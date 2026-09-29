#!/bin/sh

MISE_YES=1 mise i

# 他のパッケージやスクリプトから読み込まれるものは、ツールごとに別の場所へ入る mise の npm: ではなく、
# bun のグローバルへまとめて置く（commitizen は同じ場所の cz-conventional-changelog-ja を読み、
# playwright はスクリプトから import される）
mise exec -- bun add -g commitizen@4.3.1 cz-conventional-changelog-ja@0.0.2 playwright@1.63.0
