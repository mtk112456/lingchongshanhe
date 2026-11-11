# 国风 BGM 制作报告（AUDIO_PRODUCTION）

> 产物：`art_src/audio/generated/`（3 首，WAV 48k/16bit + OGG q6）
> 代码：`tools/audiogen/`（离线渲染管线，可重跑）
> 日期：2026-11-11　执行：OpenCode（音频子任务）

---

## 0. 一句话结论

两首可循环 BGM（`map_theme` 80s / `battle_theme` 60s）和一首 30s 胜利 sting 已完成，
全部 **-16.0 LUFS、真峰值 ≤ -2.0 dBTP、48kHz/16bit 立体声**，循环接缝经测量为无缝
（接缝跳变仅相当于本曲最大瞬态的 0.1%–1.2%）。

首选方案 **ACE-Step 1.5 没能跑起来**：不是显存问题，而是**模型权重下载被本机网络阻断**
（HuggingFace / ModelScope 的 TLS 握手被重置）。因此改用 GitHub 上的 CC0 民族乐器采样
自建离线渲染管线交付。失败点、证据和可执行的下一步见第 2 节。

---

## 1. 交付物

| 文件 | 用途 | 时长 | 格式 | 大小 |
|---|---|---|---|---|
| `art_src/audio/generated/map_theme.wav` | 大地图/经营界面 | 80.000 s | WAV 48k/16bit/2ch | 15.0 MB |
| `art_src/audio/generated/map_theme.ogg` | 游戏内实际播放 | 80.000 s | Vorbis q6 ≈192 kbps | 1.61 MB |
| `art_src/audio/generated/battle_theme.wav` | 战斗 | 60.000 s | WAV 48k/16bit/2ch | 11.2 MB |
| `art_src/audio/generated/battle_theme.ogg` | 游戏内实际播放 | 60.000 s | Vorbis q6 ≈192 kbps | 1.25 MB |
| `art_src/audio/generated/season_theme.wav` | 赛季/胜利 sting（非循环） | 30.000 s | WAV 48k/16bit/2ch | 5.6 MB |
| `art_src/audio/generated/season_theme.ogg` | 游戏内实际播放 | 30.000 s | Vorbis q6 ≈192 kbps | 0.61 MB |
| `art_src/audio/generated/qa/map_theme_loop3x.ogg` | **试听用：循环 3 遍** | 240 s | OGG | 4.71 MB |
| `art_src/audio/generated/qa/battle_theme_loop3x.ogg` | **试听用：循环 3 遍** | 180 s | OGG | 3.66 MB |
| `art_src/audio/generated/qa/*_spectrogram.png` | 频谱图（验收用） | — | PNG | ~1.4 MB |
| `art_src/audio/generated/qa/qa_summary.json` | 全部测量值（机器可读） | — | JSON | — |
| `art_src/audio/generated/raw/*_raw.wav` | 未母带的原始混音（可重新母带） | — | WAV | 31 MB |

未改动 `client/`、`server/`、`client/assets/audio/` 下任何现有音频。

---

## 2. 方案 A：ACE-Step 1.5 —— 尝试与失败点（重要）

### 2.1 调研结论（符合预期）

| 项 | 值 |
|---|---|
| 仓库 | https://github.com/ace-step/ACE-Step-1.5 |
| 本地克隆 | `tools/ACE-Step-1.5`，commit `ca1e85fe9430179831e6bc6be790c332190a3866`（2026-08-29） |
| License | **MIT**（`LICENSE` 文件确认，Copyright (c) 2026 ACEStep） |
| 官方指标 | 2B DiT 约 4.7 GB 权重，<4 GB 显存可控（含 CPU offload） |
| 支持 | 文本生成、BPM/调性/时长控制、10s–600s、纯器乐 |
| 权重分发 | **仅** HuggingFace `ACE-Step/Ace-Step1.5` 与 ModelScope `ACE-Step/Ace-Step1.5` |

就硬件而言本机是够的（RTX 4060 Laptop 8 GB，当时空闲 6.1 GB），属于官方支持范围。

### 2.2 失败点

**权重拿不到。** 本机代理（`http://127.0.0.1:7900`）对 `huggingface.co`、`cdn-lfs.huggingface.co`、
`www.modelscope.cn` 的 TLS 握手全部失败，`github.com` 正常。证据：

```text
$ curl -sv https://huggingface.co/ACE-Step/Ace-Step1.5/resolve/main/model_index.json
* CONNECT tunnel established, response 200
* schannel: failed to receive handshake, SSL/TLS connection failed
$ echo $LASTEXITCODE
35                       # CURLE_SSL_CONNECT_ERROR
```

尝试过、同样不可用的镜像/入口（全部 `000` / TLS 失败）：

`hf-mirror.com`、`hf-mirror.net`、`modelscope.cn`、`openxlab.org.cn`、`aifasthub.com`、
`ai.gitcode.com`、`hf-api.gitee.com`、`gitee.com`、`gitcode.com`、`sourceforge.net`。
`ghproxy.net` / `gh-proxy.com` 可用，但它们只能代理 GitHub，无法代理 HF LFS。
`api.github.com` 也被阻断（只有 `github.com` 网页/克隆可用）。

因此：
- ACE-Step 的 `install_uv.bat` / `start_gradio_ui.bat` 即使装完依赖，首次运行也会卡在
  `snapshot_download`，无法进入推理；
- 换 MusicGen small（audiocraft，约 5 GB VRAM）解决不了问题，**同样依赖 HF 权重**；
- 这也是为什么没有选择"Python MIDI + FluidSynth + 中国乐器 soundfont"的原始形态：
  FluidSynth 本体能从 GitHub Releases 拿到，但常见民族音色 `.sf2` 都托管在被阻断的站点
  （musical-artifacts / polyphone / 网盘）。**改为直接用 GitHub 上以 SFZ+WAV 形式发布的
  CC0 采样库**，绕开 SF2 依赖（见第 3 节）。

### 2.3 可执行的下一步（按优先级）

1. **放行域名后重跑**（最省事）。让代理规则放行 `huggingface.co`、`cdn-lfs.huggingface.co`
   （或 `modelscope.cn`），然后：
   ```powershell
   cd tools\ACE-Step-1.5
   .\install_uv.bat
   .venv\Scripts\python.exe cli.py --download-source huggingface `
       --caption "Chinese ink-wash landscape, guzheng arpeggios, erhu melody, dizi, soft percussion, 72 BPM, pentatonic, calm, spacious, no vocals, instrumental" `
       --duration 80 --format wav --save-dir ..\..\art_src\audio\ai
   ```
   （参数名以该 commit 的 `cli.py --help` 为准；显存不足时按 README 打开 CPU offload / 2B-turbo 模型。）
2. **离线搬运权重**：在可上网的机器上
   `huggingface-cli download ACE-Step/Ace-Step1.5 --local-dir checkpoints`，
   把 `checkpoints/` 整个拷到 `tools/ACE-Step-1.5/checkpoints/`，再跑上面的命令（去掉 `--download-source`）。
   该目录已被 `tools/.gitignore` 排除，不会进仓库。
3. **拿到 AI 版本后不要直接用**：扩散模型输出通常首尾不衔接、响度不稳。用本报告的
   `tools/audiogen/master.py` 做母带（EQ → 增益 → 限幅 → -16 LUFS / ≤-1 dBTP），
   并按下文方法做循环点处理，或至少做 0.5–1 s 交叉淡化。

---

## 3. 方案 B（实际采用）：CC0 采样 + 自研离线渲染

### 3.1 采样来源与许可

| 用途 | 来源 | License | 内容 |
|---|---|---|---|
| 二胡 | `sfzinstruments/aliexpress-erhu`（commit `6615047`） | **CC0 1.0** | 半音级多采样 D4–A5，sus / staccato / sul tasto，各 2 个 round-robin，44.1k 立体声 |
| 古筝 | `sparklecatta-lang/XSXB-Band-Samples`（commit `4ce222e`，仅 sparse-checkout `samples/guzheng`、`samples/xiao`） | **CC0 1.0** | 古筝 34 个采样 D2–D6（含 3 个 RR）；箫 56 个采样（中音/次中音竖笛改造） |
| 琵琶音型 | 用古筝采样 + 亮度倾斜 + 短促包络模拟（轮指） | 同上 | — |
| 战鼓 / 排鼓 / 木边 | numpy 合成（膜振动模型：音高下滑正弦 + 带限噪声 + 瞬态） | 本项目原创 | — |
| 低音弦乐铺底 | numpy 合成（3 路失谐锯齿 + 低通 + 慢包络） | 本项目原创 | — |
| 钟 / 碰铃 | numpy 合成（非谐分音加法合成） | 本项目原创 | — |
| 混响 | 合成脉冲响应（指数衰减噪声 + 早期反射），循环卷积 | 本项目原创 | — |

全部采样为 CC0（可商用、免署名）；仍建议在游戏 credits 里写一行来源，便于日后审计。

### 3.2 工具链

| 组件 | 版本 |
|---|---|
| Python | 3.12.14（`uv` 独立虚拟环境 `tools/audioenv`，未污染系统 Python 3.14） |
| numpy / scipy / soundfile | 2.5.4 / 1.18.1 / 0.14.0 |
| librosa | 仅用于调性自检（chroma） |
| ffmpeg / ffprobe | 9.0.2 full build |
| GPU | 未使用（本方案纯 CPU，渲染 3 首约 3 分钟） |

### 3.3 代码结构

```text
tools/audiogen/
  engine.py        # 采样器（变调/滑音/揉弦/换弓）、DSP、混响、总线、限幅、接缝测量
  instruments.py   # SFZ 解析 + 三件乐器的键位映射（含二胡八度偏移修正）
  make_bgm.py      # 三首曲子的编曲与渲染
  master.py        # 母带：EQ → 增益 → 前瞻限幅 → -16 LUFS / WAV + OGG
  qa.py            # 验收：ffprobe/ebur128/接缝/频段/频谱图/循环三连播
  check_engine.py  # 音高与电平自检
```

关键实现点（也是本方案能做出"无缝循环"的原因）：

1. **尾音折叠**：整首渲染到 `N + tail` 的缓冲，把越过循环点的部分（含混响尾巴）折回开头，
   于是"最后一小节的和弦余韵"会自然地出现在第 0 秒，接缝处不是静音而是延续。
2. **循环卷积混响**：第一版用线性卷积，混响在 N 处被硬切，接缝跳变 0.0175（明显）；
   改成循环卷积后降到 0.0002。
3. **换弓而非循环采样**：二胡长音超过采样长度（2.5 s）时，用 100 ms 交叉淡化"重新起弓"，
   避免揉弦相位错位产生的嗡声。
4. **母带滤波器带预热**：EQ/限幅器先把本曲尾部 0.3 s 当作 pre-roll 送进滤波器，再裁掉，
   否则 IIR 从零状态启动会在第 0 个采样上留下台阶（这也是一开始接缝"有咔哒"的真正原因）。

---

## 4. 复现命令

首次（已执行过，记录备查）：

```powershell
# 1) 独立 Python 环境
uv venv tools/audioenv --python 3.12
uv pip install --python tools/audioenv/Scripts/python.exe numpy scipy soundfile

# 2) 取 CC0 采样（GitHub 可用；HF/ModelScope 不可用）
git clone --depth 1 https://github.com/sfzinstruments/aliexpress-erhu tools/samples/erhu
git clone --depth 1 --filter=blob:none --sparse https://github.com/sparklecatta-lang/XSXB-Band-Samples tools/samples/xsxb
git -C tools/samples/xsxb sparse-checkout set samples/guzheng samples/xiao
```

日常渲染 / 母带 / 验收：

```powershell
cd tools/audiogen
..\audioenv\Scripts\python.exe check_engine.py     # 音高/电平自检
..\audioenv\Scripts\python.exe make_bgm.py map     # 渲染 -> generated/raw/map_raw.wav
..\audioenv\Scripts\python.exe make_bgm.py battle
..\audioenv\Scripts\python.exe make_bgm.py sting
..\audioenv\Scripts\python.exe master.py all       # 母带 + 导出 WAV/OGG + 测量
..\audioenv\Scripts\python.exe qa.py               # 频谱图 + 循环三连播 + qa_summary.json
```

---

## 5. 三首曲子

### 5.1 `map_theme` — 大地图 / 经营界面

**提示词（需求原文）**
> Chinese ink-wash landscape, guzheng arpeggios, erhu melody, dizi, soft percussion, 72 BPM, pentatonic, calm, spacious, no vocals, loopable, cinematic game BGM

**实际编排**（D 宫五声：D E F# A B；72 BPM；4/4；24 小节 = 80.000 s）

| 小节 | 时间 | 内容 |
|---|---|---|
| 1–4 | 0:00–0:13 | 低音弦乐持续音（D/A 空五度）+ 古筝滚奏 + 碰铃 + 箫的短句（补空，避免循环回到开头时"掉进洞里"） |
| 5–12 | 0:13–0:40 | A 段：**二胡主旋律**（A4–E5，带下滑入音），古筝八分音符分解和弦，轻打击（低音鼓 + 沙锤） |
| 13–16 | 0:40–0:53 | B 段：**箫**接旋律（上移八度），古筝转十六分音符流动 |
| 17–20 | 0:53–1:07 | A' 段：二胡回归 + 箫长音铺底 |
| 21–24 | 1:07–1:20 | 尾声：二胡落回主音 D，古筝下行**刮奏**，末小节 D 空五度和弦一直响到循环点并被折回开头 |

- 和声只用空五度（D–A / B–F# / A–E），不叠三度，保持"水墨留白"
- 打击乐极轻（能量占比 1%），只做气口
- 实测：**-16.0 LUFS / -2.0 dBTP / LRA 6.2**，80.000 s = 3,840,000 采样
- 循环点：第 0 采样 = 第 24 小节末拍（80.000 s），接缝跳变 0.0011（= 全曲 p99.9 瞬态的 1.2%），click_db 0.02 dB（不可闻）

### 5.2 `battle_theme` — 战斗

**提示词（需求原文）**
> Chinese war drums, taiko, pipa, erhu, low strings, 112 BPM, tense, heroic, no vocals, loopable game battle BGM

**实际编排**（D 羽五声：D F G A C；112 BPM；4/4；28 小节 = 60.000 s）

| 小节 | 时间 | 内容 |
|---|---|---|
| 1–2 | 0:00–0:04 | 排鼓滚奏 + 大鼓 + 低音弦乐渐强（引子） |
| 3–10 | 0:04–0:21 | A 段：**琵琶式十六分固定音型**（D-A-D-F 轮指）+ 战鼓（大鼓 1/3 拍、木边 2/4 拍、4 小节一次排鼓过门）+ **二胡英雄主题** |
| 11–18 | 0:21–0:39 | B 段：二胡上冲至 A5，低音弦乐加厚，鼓组加密 |
| 19–24 | 0:39–0:51 | A' 段：古筝低八度加倍旋律，编制最满 |
| 25–27 | 0:51–0:58 | 断奏：鼓 + 上行音阶，抽掉一半十六分音符制造"提气" |
| 28 | 0:58–1:00 | 收尾重击 + 二胡长音，直接咬回第 0 秒的大鼓 |

- 固定音型每 4 小节换一次音序（3 套轮换），第 4 小节末尾留空给鼓过门，避免机械感
- 实测：**-16.0 LUFS / -2.0 dBTP / LRA 3.6**，60.000 s = 2,880,000 采样
- 循环点：第 0 采样 = 第 28 小节末（60.000 s），接缝跳变 0.0002（p99.9 的 0.1%）
- 说明：`click_db` 报 4.72 dB，是因为**循环点正好落在大鼓重音上**——同曲内部其它小节重音的
  click_db 中位数 1.5、p90 2.9、最大 4.2，所以这是"重音"，不是爆音；采样级跳变只有 0.0002
  已经证明波形连续。

### 5.3 `season_theme` — 赛季 / 胜利 sting（可选交付，已做）

需求：长安、钟鼓、胜利感，30 s。
**编排**（D 宫；80 BPM；10 小节 = 30.000 s）：钟声两响 → 排鼓 24 击渐强 → 古筝上行刮奏 →
二胡号角式旋律（D5→A5→D6）→ 应答句 → 第 9 小节胜利和弦 + 大鼓 + 钟 → 古筝尾音 + 0.5 s 淡出。

- 实测：**-16.0 LUFS / -2.2 dBTP / LRA 8.4**，30.000 s；非循环，尾部 0.5 s 淡出（`afade`）

---

## 6. 验收数据（ffprobe / ebur128 / 自研接缝检测）

| 指标 | map_theme | battle_theme | season_theme |
|---|---|---|---|
| 时长 | 80.000 s | 60.000 s | 30.000 s |
| 采样率 / 位深 / 声道 | 48000 / 16 / 2 | 48000 / 16 / 2 | 48000 / 16 / 2 |
| 编码 | pcm_s16le | pcm_s16le | pcm_s16le |
| Integrated Loudness | **-16.0 LUFS** | **-16.0 LUFS** | **-16.0 LUFS** |
| True Peak | **-2.0 dBTP** | **-2.0 dBTP** | **-2.2 dBTP** |
| LRA | 6.2 LU | 3.6 LU | 8.4 LU |
| 循环长度（采样） | 3,840,000 | 2,880,000 | — |
| 接缝跳变 / p99.9 瞬态 | 0.0011 / 1.2% | 0.0002 / 0.1% | — |
| 接缝 click（相对邻域） | 0.02 dB | 4.72 dB（重音，见 5.2） | — |
| OGG 码率 | 192 kbps | 192 kbps | 192 kbps |

频段能量分布（相对总能量，dB）：

| 频段 | map_theme | battle_theme | season_theme |
|---|---|---|---|
| 20–80 Hz | -16.5 | -7.1 | -18.3 |
| 80–200 Hz | -12.6 | -10.8 | -12.1 |
| 200–500 Hz | -6.4 | -10.9 | -13.7 |
| 500–1200 Hz | -2.8 | -5.2 | -0.9 |
| 1200–3000 Hz | -8.5 | -6.1 | -12.3 |
| 3000–8000 Hz | -14.8 | -10.3 | -18.7 |
| 8000–16000 Hz | -30.2 | -27.8 | -29.2 |

> 读法：三首都是"中频厚、高频少"的暖色调（8 kHz 以上只有 -28 ~ -30 dB）。
> 这是真采样 + 低通铺底的自然结果，适合水墨气质；但在明亮耳机上会略显闷，
> 需要更"亮"时把 `engine.tone_balance()` 的 `highshelf 3400Hz` 从 +2.4 dB 调到 +3.5 dB，
> 重跑 `master.py` 即可（不用重新编曲）。

---

## 7. 试听建议

1. **先听循环三连播**（能直接暴露接缝问题）：
   - `art_src/audio/generated/qa/map_theme_loop3x.ogg` — 听 1:20 / 2:40 两个接缝
   - `art_src/audio/generated/qa/battle_theme_loop3x.ogg` — 听 1:00 / 2:00 两个接缝
2. 音量：三首都是 -16 LUFS，正常监听音量即可，不需要为某一首调音量。
3. `map_theme` 重点听：
   - 0:00–0:13 引子是否"太空"（已加箫的短句补偿，但仍是有意留白）
   - 0:40–0:53 十六分音符段落是否偏密（这是全曲最"满"的地方）
   - 1:20 → 0:00 的接缝：应该听不出"从头开始"，只听到和弦自然延续
4. `battle_theme` 重点听：
   - 0:00 的大鼓是否过重（低频 -7 dB，笔记本喇叭可能听不出，耳机上偏多）
   - 0:39 之后 A' 段编制是否过满
   - 1:00 → 0:00：循环点落在重音上是设计意图，听感应是"一口气接上"，不是"咔"
5. `season_theme`：0:00 钟声起、0:22 胜利和弦、0:29.5 淡出。

---

## 8. 质量自评

| 维度 | 分数 | 说明 |
|---|---|---|
| 音色真实度 | 8/10 | 二胡/古筝/箫是**真采样**（CC0，半音级多采样）；鼓、低音弦乐、钟是合成，战鼓的"皮"感不如实录 |
| 编曲 | 6.5/10 | 功能性强（该抒情抒情、该推进推进），但旋律朴素、发展手法有限；同一段落在 80 s 内重复 3 次，长时间挂机会腻 |
| 混音 | 7/10 | 层次干净（主旋律领先伴奏约 3–5 dB），但低频偏重、8 kHz 以上偏暗；battle 的 20–80 Hz 比 map 高 9 dB，切场景时会有"低频跳变"感 |
| 循环工程 | 9/10 | 采样级无缝（0.0002–0.0011），混响尾巴正确折回；扣 1 分是因为 battle 的循环点压在大鼓上，个别设备可能听出"打点" |
| 工程可维护 | 9/10 | 全参数化脚本，改 BPM/编制/混音后一条命令重出；不依赖 GPU、不依赖联网 |
| 综合可用性 | 8/10 | 可直接进 Godot；离"商用发行级"还差一版人耳混音 |

**必须说明**：本会话没有音频输出通道，以上结论来自**测量 + 频谱图 + 编曲意图**，
不是人耳试听结论。请务必按第 7 节实际听一遍，特别是接缝和低频。

---

## 9. 不足与风险

1. **不是 AI 生成的**：旋律是脚本写死的，创意上限低于 ACE-Step/Suno 这类模型；
   但换来的是完全可控的循环点和零版权风险。
2. **二胡音域只有 D4–A5**：超出范围靠变调（最多 +5 半音），`season_theme` 的 D6 已经是
   变调极限，音色会偏薄。
3. **打击乐是合成的**：大鼓/排鼓的瞬态和"皮膜"细节不如实录，安静段落单听会露怯。
4. **高频偏少**：见第 6 节频段表；如需明亮，改 EQ 重母带即可。
5. **`map_theme` 引子 13 s 偏静**：为了"spacious"有意为之，但游戏里如果玩家 10 秒内就
   打开菜单，可能听不到主旋律。若需要，可把 A 段提前到第 3 小节（改 `make_bgm.py` 的
   `mel_a` 小节号即可）。
6. **OGG/Vorbis 与 WAV 的循环点**：Godot 的 `AudioStreamOggVorbis.loop` 会按文件长度循环，
   Vorbis 有 pre-skip，实测 ffprobe 时长正好 80.000/60.000 s；若在引擎里听到 1–2 ms 的
   间隙，改用 WAV 或把 `loop_offset` 设为 0。
7. **未做真实学生试听**：是否符合"帮助学生判断局势"的目标，需要按 `AGENTS.md` 第 8 节
   的 8–12 人切片去验证。

---

## 10. 下一步建议

1. **打通网络后跑 ACE-Step 做 A/B**（第 2.3 节），同 prompt 出 2 版，与本版对比
   "耐听度 / 国风味 / 循环可用性"。这一步只需要放行两个域名。
2. **AI 版本必须过后处理**：扩散模型输出通常不能直接循环，用 `master.py` 统一到
   -16 LUFS 并做接缝处理，否则会出现"每 60 秒断一次"。
3. **接客户端**（需 Antigravity 同意，本任务未改 client）：
   `map_theme.ogg → client/assets/audio/bgm/map.ogg`、`battle_theme.ogg → battle.ogg`，
   Godot 里 `AudioStreamOggVorbis.loop = true`；现有 `map.wav/battle.wav` 是 22.05 kHz 单声道
   占位素材，替换后注意 `project.godot` 的音频总线音量不要重复衰减。
4. **人耳混音一版**：重点修 battle 的低频（20–80 Hz 减 2–3 dB）和整体 air（+1 dB @ 6 kHz）。
5. **素材归档**：采样库（`tools/samples/`）已加进 `tools/.gitignore`，不会进仓库；
   CC0 来源已记录在第 3.1 节，建议同步进 `THIRD_PARTY_NOTICES.md`（本任务未改该文件）。

---

## 11. 许可与合规

- 采样：**CC0 1.0**（aliexpress-erhu、XSXB-Band-Samples），可商用、可修改、免署名。
- 合成音色 / 编曲 / 渲染代码：本项目原创。
- 未使用任何商业音源、未反编译商业游戏、未复制 Unciv 资源。
- 未把任何模型权重、采样库、`.env` 或凭据写入仓库（`tools/.gitignore` 已排除）。
- 未执行 `git commit` / `git push`。
