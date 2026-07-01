# 🪨 FitRock

> **像岩石一样积累每一次训练。**
> 一款用 SwiftUI 写的离线健身记录 iOS App。

**FitRock 不是又一个云端健身平台**——你的训练数据全部存在本机 SQLite 里，
没有账号、没有广告、没有订阅。你只管练，App 只管记。

---

## ✨ 核心特性

- 📅 **月历训练视图** — 7 列表格 + 身体部位彩色点标记，月底一眼看到训练节奏
- ⏱️ **训练计时 + 自动恢复** — App 启动时检测未完成训练，弹窗询问「恢复」还是「放弃」
- 🔄 **预填上次重量/次数 (Prefill Toggle)** — 同动作自动读取上次的 weight × reps，开练不靠记忆
- 📊 **月统计卡片** — 月训练次数 / 连续打卡天数 / 月均吨位 (T) 三项一屏看全
- 🏋️ **支持多单位** — weight(kg) / reps(次) / duration(分钟) 三种动作单位自由切换
- ➕ **用户自建动作** — 内置动作库不够用？自己加
- 🧱 **模板 + PR** — 支持训练模板、从模板开练、个人记录评估与历史事件
- 🏋️‍♂️ **双模式动作库** — 按肌肉图谱浏览 DB 动作，或按器械浏览本地 JSON 教学内容
- 🔥 **肌肉热力图** — 将训练量映射到具体肌肉，查看近期偏重和遗漏肌群
- 🗓️ **4 周训练计划** — 基于历史训练、可选健康数据和用户目标生成月周期计划
- 🗃️ **纯本地 SQLite** — 用 [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift) 直接读写，零网络依赖
- 🌓 **强制深色模式** — 为健身房低光环境设计，亮色模式根本不给你选项

---

## 🛠️ 技术栈

| 层 | 选型 | 理由 |
|---|---|---|
| **UI** | SwiftUI + Combine | iOS 16+ 原生，状态驱动，开发效率高 |
| **持久化** | SQLite.swift ≥ 0.15.0 | 比 Core Data 透明，比 SwiftData 稳定（生产可用） |
| **架构** | SwiftUI MVVM + Repository Protocols | ViewModel 通过协议依赖数据层，便于单测 |
| **项目生成** | XcodeGen | `project.yml` 描述，`xcodegen generate` 即可 |
| **测试** | XCTest + XCUITest | 本地单测与 UI 自动化测试 |
| **最低 iOS** | 16.0 | 覆盖 ~95% 在用 iPhone 设备 |
| **Swift** | 5.9 | 严格并发还未启用，但 `async/await` 可用 |

---

## 🏛️ 架构

```
FitRock/
├── App/                  # 入口 (FitRockApp.swift + ContentView.swift)
│   └── AppState          # 全局未完成训练恢复逻辑
├── Core/
│   ├── Database/         # DatabaseManager facade + Repository protocols + SQLite migration
│   ├── Models/           # Workout / Exercise / Template / PR / JSON models
│   └── Services/         # PRService / LocalExerciseDataService / resource validation
├── Features/             # 主要功能模块（每模块 = View + ViewModel）
│   ├── Home/             # 月历 + 统计卡片
│   ├── Record/           # 训练中：计时 / 增删动作 / 完成 / 取消
│   ├── ExerciseLibrary/  # 双模式动作库：肌肉 / 器械
│   ├── Templates/        # 训练模板
│   ├── Stats/            # 训练历史 + 容量趋势 + PR
│   └── Settings/         # 设置（目前是版本号占位）
├── Shared/               # Theme + HapticManager
├── Resources/            # Assets + Data JSON + ExerciseImages folder reference
├── FitRockTests/         # 业务单测、仓储测试、资源一致性测试
├── FitRockUITests/       # 关键 UI 流程自动化
└── AppIcon/              # 设计资源
```

**数据流**（一次训练的全过程）：

```
[User 启动训练]
   └─▶ RecordViewModel.startWorkout()
         ├─▶ Workout() 创建内存对象
         ├─▶ Timer.scheduledTimer 开始计时
         ├─▶ Haptic.medium 震动反馈
         └─▶ DatabaseManager.saveWorkout() 落盘

[User 增/删动作]
   └─▶ RecordView 触发 ViewModel 状态更新
         └─▶ @Published workoutExercises 推送 UI

[User 完成]
   └─▶ RecordViewModel.finishWorkout()
         ├─▶ workout.endTime = Date()
         ├─▶ workout.isCompleted = true
         ├─▶ DatabaseManager.saveWorkout() (upsert)
         └─▶ Haptic.success 震动反馈
```

---

## 🚀 快速开始

```bash
# 1. 克隆
git clone https://github.com/jerryxrock-droid/FitRock.git
cd FitRock

# 2. 安装 XcodeGen（如果还没装）
brew install xcodegen

# 3. 生成 .xcodeproj
xcodegen generate

# 4. 用 Xcode 打开
open FitRock.xcodeproj
```

**首次运行**会做：
1. 在 app sandbox 的 `Documents/fitrock.sqlite3` 创建数据库
2. 创建 SQLite 表并执行幂等迁移
3. Seed 内置动作库
4. 加载本地 JSON 器械库与动作图片资源

---

## 🗃️ 数据模型

```sql
workouts           (id, start_time, end_time, is_completed)
workout_exercises  (id, workout_id, exercise_id, exercise_name, body_part)
exercise_sets      (id, workout_exercise_id, set_number, weight, reps, set_type, is_completed)
exercises          (id, exercise_name, body_part, description, is_user_created, unit)
workout_templates
workout_template_exercises
workout_template_sets
exercise_prs
pr_events
```

**7 个身体部位**：chest / back / shoulders / arms / legs / core / cardio

**3 种 set 类型**：normal / warmup / dropSet

**3 种动作单位**：weight(kg) / reps(次) / duration(分钟)

迁移策略：`migrateSchemaIfNeeded()` 检查缺列，缺就 `ALTER TABLE`，幂等可重入。

---

## 🧪 本地测试

```bash
# 重新生成工程
xcodegen generate

# 编译 App 与测试 target（不需要签名）
xcodebuild build-for-testing \
  -project FitRock.xcodeproj \
  -scheme FitRock \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO

# 单元测试（需要可用 iOS Simulator）
xcodebuild test \
  -project FitRock.xcodeproj \
  -scheme FitRock \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FitRockTests

# UI 测试（需要可用 iOS Simulator）
xcodebuild test \
  -project FitRock.xcodeproj \
  -scheme FitRock \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:FitRockUITests
```

测试覆盖：
- `StatsCalculatorTests`：统计周期、总量、身体部位分布、动作排行
- `PRServiceTests`：最大重量、容量、时长 PR、PR rebuild
- `RepositoryTests`：临时 SQLite 训练/动作/模板读写、迁移幂等
- `LocalExerciseDataServiceTests`：20 个器械、26 个动作、肌群映射、图片引用完整性
- `ViewModelTests`：动作库过滤、统计错误回落
- `FitRockUITests`：启动、Tab 导航、训练/动作库/统计冒烟流程
- `MuscleHeatmapCalculatorTests`：具体肌肉热力图、时间范围、JSON/DB 映射
- `TrainingPlanRecommendationEngineTests`：4 周计划推荐、目标差异、HealthKit 可选输入
- `TrainingPlanCompletionTests`：训练完成后自动匹配计划日、完成率

当前资源：`exercises.json` 有 52 个图片引用，其中 48 个唯一 JPG 文件，均已存在于 `Resources/ExerciseImages/`。

---

## 🧠 开发哲学

> "implement, break, fix" — 写代码前先想清楚为什么这么写，写完故意找漏洞，修，再写下一个。

- **本地优先** — 不连云就不会有云断的那一天
- **显式优于隐式** — SQLite.swift 写 SQL，不靠 ORM 推测
- **可恢复优于可丢弃** — App 被强杀？下次启动弹窗恢复训练

---

## 🗺️ Roadmap

- [ ] HealthKit 双向同步（Apple 健康里也能看到）
- [x] 训练计划模板（Push/Pull/Legs）
- [ ] 训练容量趋势图增强（折线图、周期对比）
- [ ] Apple Watch 配套 App
- [ ] iCloud 同步（可选、可关闭、端到端加密）
- [ ] 导出训练数据为 CSV

---

## 🤝 贡献

Issue / PR 都欢迎。但请遵守：
1. 一个 PR 只解决一个问题
2. 改 schema 必须同时改 `migrateSchemaIfNeeded()`
3. 不引入网络依赖

---

## 📜 License

MIT License — 你拿去改、用、卖都行，别告我就行。

---

## 👤 作者

**谢捷 (Jie Xie)** · [@jerryxrock-droid](https://github.com/jerryxrock-droid)

10 年车联网产品经理转型中。FitRock 是我学习 SwiftUI / Combine / SQLite 的练手项目——
它能跑起来是因为 iOS 16+ 终于让 SwiftUI 像个样子了。

如果这个项目帮到了你训练，点个 ⭐ 是最大的支持。
