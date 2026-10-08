/**
 * 画面を操作しながら、静止画と動画を撮るための部品。シナリオのスクリプトから import して使う。
 *
 *   import { record, waitForStable } from '~/.claude/skills/capture-results/scripts/record.mjs'
 *   await record('save-memo', { state: 'state/agent.json' }, async (page, shot) => {
 *     await page.goto(`${BASE}/settings`)
 *     await shot('before')
 *   })
 *
 * 環境変数:
 *   BASE_URL  開く画面の起点（既定 http://localhost:3000）
 *   OUT_DIR   画像と動画の出力先（必須）
 *   MASK      塗りつぶす語。「,」か「、」区切り。長い語から順に当てる
 *   BLOCK     遮断する通信の正規表現（既定は外部フォントと解析タグ）
 *   NO_CORS   1 なら撮影用のブラウザで CORS の検査を外す（別ポートから API を呼ぶとき）
 *
 * ログインはここでしない。別の context でログインして storageState を保存し、`state` に渡す。
 * 録画は context の生存期間すべてに掛かるので、同じ context でログインすると認証情報が映る。
 *
 * Playwright はグローバル（bun）のものを使う。ブラウザが足りなければ次で入れる:
 *   node ~/.bun/install/global/node_modules/playwright-core/cli.js install chromium
 */
import { createRequire } from 'node:module'
import { mkdirSync } from 'node:fs'
import { join } from 'node:path'
import { homedir } from 'node:os'

const require = createRequire(import.meta.url)
const { chromium: pw } = require(join(homedir(), '.bun/install/global/node_modules/playwright'))

export const BASE = process.env.BASE_URL || 'http://localhost:3000'
export const OUT = process.env.OUT_DIR
export const VIEWPORT = { width: 1440, height: 900 }
if (!OUT) throw new Error('OUT_DIR を指定してください')
mkdirSync(OUT, { recursive: true })

// 外部のフォントと解析タグは確かめる内容に関係せず、返らないと読み込みが止まることがある
const BLOCK = new RegExp(process.env.BLOCK || 'fonts\\.googleapis|fonts\\.gstatic|google-analytics|googletagmanager|doubleclick')

/** 撮影用のブラウザを起動する。作る context はすべて BLOCK の通信を遮断する */
export async function launch(options = {}) {
  const args = [...(options.args || []), ...(process.env.NO_CORS ? ['--disable-web-security'] : [])]
  const browser = await pw.launch({ ...options, args })
  const newContext = browser.newContext.bind(browser)
  browser.newContext = async (...a) => {
    const ctx = await newContext(...a)
    await ctx.route(BLOCK, r => r.abort())
    return ctx
  }
  return browser
}

/**
 * 描画が落ち着くまで待つ。networkidle は通信が止まっただけで、
 * 再描画やアニメーションは終わっていないので、DOM の変化が止まるまで待つ
 */
export async function waitForStable(page, { quietMs = 700, timeoutMs = 20000 } = {}) {
  await page.waitForLoadState('networkidle').catch(() => {})
  await page.evaluate(
    ({ quietMs, timeoutMs }) =>
      new Promise(resolve => {
        const deadline = Date.now() + timeoutMs
        let timer
        const observer = new MutationObserver(() => bump())
        const done = () => { observer.disconnect(); resolve() }
        const bump = () => { clearTimeout(timer); timer = setTimeout(done, quietMs) }
        observer.observe(document.body, { childList: true, subtree: true, attributes: true })
        bump()
        setTimeout(done, Math.max(0, deadline - Date.now()))
      }),
    { quietMs, timeoutMs },
  )
}

const maskTerms = () =>
  [...new Set((process.env.MASK || '').split(/[,、]/).map(t => t.trim()).filter(Boolean))].sort((a, b) => b.length - a.length)

/**
 * 塗りつぶしの漏れを数える。画面の innerText に MASK の語が残っていれば、その語を返す。
 * 塗りつぶしは文字の置き換えなので、画像の見た目ではなく文字で確かめる
 */
export async function leakedTerms(page) {
  const text = await page.evaluate(() => document.body.innerText)
  return maskTerms().filter(t => text.includes(t))
}

/**
 * 1つの確認を録画する。fn(page, shot) の中で操作し、shot(label) で静止画を撮る。
 * 撮るたびに塗りつぶしの漏れを数え、漏れがあれば失敗にして動画を消す
 */
export async function record(name, { state, routes } = {}, fn) {
  const browser = await launch()
  const ctx = await browser.newContext({ viewport: VIEWPORT, storageState: state, recordVideo: { dir: OUT, size: VIEWPORT } })
  if (routes) await routes(ctx)
  const terms = maskTerms()
  if (terms.length) {
    await ctx.addInitScript(names => {
      const re = new RegExp(names.map(n => n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|'), 'g')
      const fix = root => {
        const w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
        for (let n = w.nextNode(); n; n = w.nextNode()) {
          if (re.test(n.nodeValue)) n.nodeValue = n.nodeValue.replace(re, m => '■'.repeat(m.length))
          re.lastIndex = 0
        }
      }
      new MutationObserver(ms => ms.forEach(m => fix(m.target))).observe(document, { subtree: true, childList: true, characterData: true })
      document.addEventListener('DOMContentLoaded', () => fix(document.body))
    }, terms)
  }
  const page = await ctx.newPage()
  const video = page.video()
  const shots = []
  const shot = async label => {
    await waitForStable(page)
    const leaked = await leakedTerms(page)
    if (leaked.length) throw new Error(`塗りつぶしが漏れた: ${leaked.length}語`)
    const p = join(OUT, `${name}-${label}.png`)
    await page.screenshot({ path: p })
    shots.push(p)
  }
  let error
  try {
    await fn(page, shot)
    await page.waitForTimeout(1500)
  } catch (e) {
    error = e
  }
  // 動画は context を閉じると書き終わり、ブラウザを閉じると保存も削除もできなくなる
  await ctx.close()
  const webm = join(OUT, `${name}.webm`)
  if (error) await video.delete()
  else {
    // saveAs は写しを作るだけで、元の page@<id>.webm は残る
    await video.saveAs(webm)
    await video.delete()
  }
  await browser.close()
  console.log(JSON.stringify({ name, ok: !error, error: error?.message?.split('\n')[0], shots, video: error ? null : webm }))
  if (error) process.exitCode = 1
}
