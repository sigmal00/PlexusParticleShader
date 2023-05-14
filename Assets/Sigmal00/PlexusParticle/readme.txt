Plexus Particle

# 概要
近くのパーティクル同士が線で結ばれるエフェクトです。
レンダーテクスチャなどは使用していないのでプレハブポン置きで使えます。

# マテリアルパラメータ説明
## Color
パーティクルの色です。Particle System側で設定した色に乗算されます。

## Particle Size
パーティクルの大きさです。Particle System側で設定した大きさに乗算されます。

## Line Width
パーティクル同士を結ぶ線の太さです。Particle System側で設定した大きさに乗算されます。

## Connect Distance
パーティクル同士が線で結ばれる距離です。

## Fade Distance
線がフェードするまでの距離です。
例えばConnect Distanceが2.0，Fade Distanceが0.5のとき、パーティクル同士の距離が1.5のとき線はフェードを始め、2.0のとき完全に透明になります。