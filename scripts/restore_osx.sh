#!/bin/sh

#
# Finder
#

# 隠しファイルを表示
defaults write com.apple.finder AppleShowAllFiles -bool true

# すべての拡張子のファイルを表示
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# ステータスバーを表示
defaults write com.apple.finder ShowStatusBar -bool true

# パスバーを表示
defaults write com.apple.finder ShowPathbar -bool true

# ドライブをデスクトップに表示
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true

killall Finder

# ネットワークストレージに .DS_Store ファイルを作成しない
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# USBメモリに .DS_Store ファイルを作成しない
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

#
# Energy Saver
#

## sudo を最初にここで通し、以降は聞かれないようにする。
# defaults の適用は数分かかることがあり、途中で再入力を求められると止まる
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

# 電源接続中はスリープしない
sudo pmset -c sleep 0

# 電源接続中はディスプレイを消さない
sudo pmset -c displaysleep 0

# スクリーンセーバを開始しない。
# ロックの契機は画面が消えることなので、AC 電源では発動しなくなる。
# バッテリー時は displaysleep が効くため、そちらではロックが残る。
defaults -currentHost write com.apple.screensaver idleTime -int 0

#
# Security
#

# ファイアーウォールをオン
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

#
# Dock
#

# 「自動的に非表示」をオン
defaults write com.apple.dock autohide -bool true

# 最近使ったアプリケーションを非表示
defaults write com.apple.dock show-recents -bool false

killall Dock

#
# SystemUIServer
#

# 時計で日付を表示（例：9月20日(木) 23:00）
defaults write com.apple.menuextra.clock DateFormat -string 'EEE MMM d HH:mm'

# バッテリーの割合（%）を表示
defaults write com.apple.menuextra.battery ShowPercent -string 'YES'

# スクリーンショットのドロップシャドウを付けない
defaults write com.apple.screencapture disable-shadow -bool true

killall SystemUIServer

#
# Safari
#

# アドレスバーに完全な URL を表示
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# ファイルのダウンロード後に自動でファイルを開くのを無効化
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# メニューバーに「開発」を表示
defaults write com.apple.Safari IncludeDevelopMenu -bool true

# デバッグメニューをオン
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# ステータスバーを表示
defaults write com.apple.Safari ShowStatusBar -bool true

killall Safari

#
# TextEdit
#

# リッチテキストから標準テキストに変更
defaults write com.apple.TextEdit RichText -int 0

#
# 書き出した設定の取り込み
#
# 上の defaults write は「最低限こうしたい」を表す。旧マシンの書き出しが
# あればそれで上書きし、GUI から変えた設定まで引き継ぐ。
# 書き出しが無い場合（初回など）は上の既定値のまま進む。
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

import_macos_defaults "$ROOT/private/.macos-defaults"

# 取り込んだ内容を反映させる。起動していないものは失敗して構わない
for app in Finder Dock SystemUIServer ControlCenter; do
  killall "$app" 2>/dev/null || true
done

apply_associations "$ROOT/private/.associations/duti.txt"

KEYBOARD="$ROOT/private/.keyboard/text-replacements.tsv"
if [ -f "$KEYBOARD" ]; then
  echo "   テキスト置換 $(wc -l < "$KEYBOARD" | tr -d ' ')件は自動で戻りません。"
  echo "   iCloud 同期が有効なら自動、そうでなければ $KEYBOARD を見て手で入れてください"
fi

echo "👍 OSX のリストアが完了しました"
