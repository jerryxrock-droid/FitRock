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
- 🗃️ **纯本地 SQLite** — 用 [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift) 直接读写，零网络依赖
- 🌓 **强制深色模式** — 为健身房低光环境设计，亮色模式根本不给你选项

---

## 🛠️ 技术栈

| 层 | 选型 | 理由 |
|---|---|---|
| **UI** | SwiftUI + Combine | iOS 16+ 原生，状态驱动，开发效率高 |
| **持久化** | SQLite.swift ≥ 0.15.0 | 比 Core Data 透明，比 SwiftData 稳定（生产可用） |
| **架构** | MVVM (View + ViewModel + ObservableObject) | 4 个 feature 模块独立可测试 |
| **项目生成** | XcodeGen | `project.yml` 描述，`xcodegen generate` 即可 |
| **最低 iOS** | 16.0 | 覆盖 ~95% 在用 iPhone 设备 |
| **Swift** | 5.9 | 严格并发还未启用，但 `async/await` 可用 |

---

## 🏛️ 架构

```
FitRock/
├── App/                  # 入口 (FitRockApp.swift + ContentView.swift)
│   └── AppState          # 全局未完成训练恢复逻辑
├── Core/
│   ├── Database/         # DatabaseManager — SQLite 单例 + 4 张表 + 自动 migration
│   └── Models/           # Workout / WorkoutExercise / Exercise / ExerciseSet / Enums
├── Features/             # 4 大模块（每模块 = View + ViewModel）
│   ├── Home/             # 月历 + 统计卡片
│   ├── Record/           # 训练中：计时 / 增删动作 / 完成 / 取消
│   ├── Stats/            # 训练历史 + 容量趋势
│   └── Settings/         # 设置（目前是版本号占位）
├── Shared/               # Theme + HapticManager
├── Resources/            # Assets.xcassets
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
2. 创建 4 张表（workouts / workout_exercises / exercise_sets / exercises）
3. Seed 内置动作库
4. 跑 schema migration（添加 `is_user_created` + `unit` 字段）

---

## 🗃️ 数据模型（4 张表）

```sql
workouts           (id, start_time, end_time, is_completed)
workout_exercises  (id, workout_id, exercise_id, exercise_name, body_part)
exercise_sets      (id, workout_exercise_id, set_number, weight, reps, set_type, is_completed)
exercises          (id, exercise_name, body_part, description, is_user_created, unit)
```

**7 个身体部位**：chest / back / shoulders / arms / legs / core / cardio

**3 种 set 类型**：normal / warmup / dropSet

**3 种动作单位**：weight(kg) / reps(次) / duration(分钟)

迁移策略：`migrateSchemaIfNeeded()` 检查缺列，缺就 `ALTER TABLE`，幂等可重入。

---

## 🧠 开发哲学

> "implement, break, fix" — 写代码前先想清楚为什么这么写，写完故意找漏洞，修，再写下一个。

- **本地优先** — 不连云就不会有云断的那一天
- **显式优于隐式** — SQLite.swift 写 SQL，不靠 ORM 推测
- **可恢复优于可丢弃** — App 被强杀？下次启动弹窗恢复训练

---

## 🗺️ Roadmap

- [ ] HealthKit 双向同步（Apple 健康里也能看到）
- [ ] 训练计划模板（Push/Pull/Legs）
- [ ] 训练容量趋势图（折线图）
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
