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

echo "👍 OSX のリストアが完了しました"
