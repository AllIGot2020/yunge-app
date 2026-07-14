// 生成安卓自适应图标前景层：徽章缩到 66% 居中，四周透明留边
const sharp = require("sharp");
const fs = require("fs");

const SRC = "C:/Users/1/yunge-app/assets/yunge/icon.png";
const OUT_FG = "C:/Users/1/yunge-app/assets/yunge/icon_foreground.png";

(async () => {
  const size = 1024;
  const inner = Math.round(size * 0.66); // 前景内容占 66%
  const badge = await sharp(SRC).resize(inner, inner).png().toBuffer();
  // 透明画布，居中贴徽章
  await sharp({
    create: {
      width: size,
      height: size,
      channels: 4,
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    },
  })
    .composite([{ input: badge, gravity: "center" }])
    .png()
    .toFile(OUT_FG);
  console.log("foreground ready");
})();
