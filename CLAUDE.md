# FitRock 开发规范与记录

## 项目概述

- **项目名称**: FitRock
- **Bundle ID**: com.fitrock.FitRock
- **iOS版本**: iOS 16.0+
- **技术栈**: SwiftUI + SQLite.swift
- **架构**: MVVM + Repository
- **创建日期**: 2026-04-30
- **最后更新**: 2026-05-02

---

## iOS 开发规范

### 编码标准
- Xcode编译零报错
- 长时间任务预估、进度汇报规范
- 使用Theme.Colors/Theme.Fonts/Theme.Spacing管理样式
- 避免硬编码颜色和字号

### 全屏适配要求
- 所有视图使用 `.ignoresSafeArea()` 确保填满屏幕
- TabBar/NavigationBar配置不透明背景与主题一致
- 背景色延伸到安全区域

### UI组件规范
- 颜色定义在 `Theme.swift` 的 `Colors` 枚举
- 字体定义在 `Theme.swift` 的 `Fonts` 枚举
- 间距定义在 `Theme.swift` 的 `Spacing` 枚举
- 圆角定义在 `Theme.swift` 的 `CornerRadius` 枚举

---

## 产品需求 (PRD)

### 核心功能
1. **Tab导航**: 3个Tab（日历/训练/统计）
2. **日历视图**: 显示训练历史，日期标记多部位彩色圆点
3. **训练记录**: 动作搜索、添加组、上次训练参考、结束训练
4. **统计展示**: 训练次数、容量、时长、组数、部位分布、动作排行、PR纪录
5. **深色主题**: 背景 #121212， accent #FF5722
6. **30个预置动作**: 覆盖7个身体部位

### 已实现功能
- [x] Tab导航结构
- [x] 日历视图（含日期选择、训练标记）
- [x] 训练记录完整流程
- [x] 统计页面（本周/本月/全部）
- [x] 30个预置动作
- [x] 深色主题
- [x] 上次训练参考
- [x] 杀进程恢复（未完成训练保存）
- [x] 触感反馈
- [x] 单位白色显示（kg/次）
- [x] 全屏适配
- [x] 删除确认弹窗
- [x] 训练卡片动作列表预览
- [x] 继续上次训练功能
- [x] 动作搜索部位筛选
- [x] PR个人纪录追踪
- [x] 日历多部位标记

### 未实现功能
- [ ] 递减组功能
- [ ] 组间休息计时
- [ ] 数据导出
- [ ] 训练提醒

---

## 技术架构

### 文件结构
```
FitRock/
├── App/
│   ├── FitRockApp.swift      # App入口、AppState、appearance配置
│   └── ContentView.swift     # TabView主视图
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift    # 日历主页
│   │   └── HomeViewModel.swift
│   ├── Record/
│   │   ├── RecordView.swift   # 训练记录页
│   │   ├── RecordViewModel.swift
│   │   ├── ExerciseSearchView.swift
│   │   └── WorkoutSummaryView.swift
│   ├── Stats/
│   │   ├── StatsView.swift   # 统计页
│   │   └── StatsViewModel.swift
│   └── Settings/
│       └── SettingsView.swift
├── Core/
│   ├── Database/
│   │   └── DatabaseManager.swift  # SQLite操作
│   └── Models/
│       ├── Workout.swift
│       ├── WorkoutExercise.swift
│       ├── Exercise.swift
│       ├── ExerciseSet.swift
│       └── Enums.swift
└── Shared/
    ├── Theme.swift            # 颜色/字体/间距/圆角
    └── HapticManager.swift    # 触感反馈
```

### 数据库设计

**Table: workouts**
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT (PK) | 训练ID |
| start_time | DATE | 开始时间 |
| end_time | DATE? | 结束时间 |
| is_completed | BOOL | 是否完成 |

**Table: workout_exercises**
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT (PK) | 动作ID |
| workout_id | TEXT (FK) | 关联训练 |
| exercise_id | TEXT | 动作ID |
| exercise_name | TEXT | 动作名称 |
| body_part | TEXT | 部位 |

**Table: exercise_sets**
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT (PK) | 组ID |
| workout_exercise_id | TEXT (FK) | 关联动作 |
| set_number | INT | 组号 |
| weight | DOUBLE | 重量 |
| reps | INT | 次数 |
| set_type | TEXT | normal/warmup/dropSet |
| is_completed | BOOL | 是否完成 |

**Table: exercises**
| Column | Type | Description |
|--------|------|-------------|
| id | TEXT (PK) | 动作ID |
| exercise_name | TEXT | 动作名称 |
| body_part | TEXT | 部位 |
| description | TEXT | 描述 |

### 预置动作 (30个)
- 胸部(4): 杠铃卧推、哑铃卧推、双杠臂屈伸、哑铃飞鸟
- 背部(4): 高位下拉、坐姿划船、引体向上、直臂下压
- 肩部(4): 杠铃推举、哑铃侧平举、前平举、俯身飞鸟
- 手臂(6): 杠铃弯举、哑铃弯举、锤式弯举、窄距卧推、绳索下压、过顶伸展
- 腿部(6): 深蹲、腿举、腿弯举、腿伸展、罗马尼亚硬拉、小腿提踵
- 核心(5): 卷腹、平板支撑、悬垂举腿、俄语转体、山羊挺身
- 有氧(1): 跑步机

---

## 开发记录

### 2026-04-30: 项目创建
- 创建FitRock项目，使用XcodeGen生成
- 实现3个Tab导航和基础UI结构
- 配置SQLite.swift数据库

### 2026-05-01: 功能迭代
- 实现上次训练参考功能
- 实现杀进程恢复功能
- 实现触感反馈
- 单位白色显示修复
- 全屏适配多次迭代

### 2026-05-02: P0/P1问题修复
**P0问题（已修复）**:
1. 删除操作加确认弹窗 - swipeActions设置allowsFullSwipe=false，添加确认对话框
2. 日期训练卡片增加动作列表预览 - WorkoutSummaryCard显示最多4个动作名
3. 添加"继续上次训练"功能 - 检测未完成训练，提供继续/放弃选项

**P1问题（已修复）**:
1. 动作搜索增加部位筛选 - FilterChip组件，支持7个部位筛选
2. 统计页增加PR标识 - PersonalRecord结构追踪每个动作最大重量
3. 日历训练标记支持多部位 - 显示最多3个彩色小圆点

**其他改进**:
- 计时器改为Date-based计算，锁屏后恢复仍准确

---

## 设计规范

### 主题颜色
```swift
Colors.accent      // #FF5722 橙色
Colors.background   // #121212 深色背景
Colors.surface     // #1E1E1E 卡片背景
Colors.surface2    // #242424 次级卡片
Colors.textPrimary  // #F0ECE4 主文字
Colors.textSecondary // #8A8580 次级文字
Colors.textMuted    // #5A5550 弱化文字
Colors.success      // #4CAF50 成功
Colors.warning      // #FF9800 警告
```

### 身体部位颜色
```swift
chest     // #FF5722 橙色
back      // #2196F3 蓝色
shoulders // #FF9800 橙色
arms      // #9C27B0 紫色
legs      // #4CAF50 绿色
core      // #FFC107 黄色
cardio    // #9E9E99 灰色
```

### 字体规范
```swift
Fonts.largeTitle  // 34pt bold
Fonts.title       // 22pt semibold
Fonts.headline    // 17pt semibold
Fonts.body        // 16pt regular
Fonts.caption     // 13pt regular
Fonts.mono        // 16pt monospaced
```

### 间距规范
```swift
Spacing.xs  // 4pt
Spacing.sm  // 8pt
Spacing.md  // 16pt
Spacing.lg  // 24pt
Spacing.xl  // 32pt
```

### 圆角规范
```swift
CornerRadius.small  // 10pt
CornerRadius.medium // 16pt
CornerRadius.large  // 20pt
```

---

## 关键代码片段

### 全屏适配配置
```swift
// FitRockApp.swift
init() {
    let tabBarAppearance = UITabBarAppearance()
    tabBarAppearance.configureWithOpaqueBackground()
    tabBarAppearance.backgroundColor = UIColor(Theme.Colors.background)
    UITabBar.appearance().standardAppearance = tabBarAppearance
    UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

    let navBarAppearance = UINavigationBarAppearance()
    navBarAppearance.configureWithOpaqueBackground()
    navBarAppearance.backgroundColor = UIColor(Theme.Colors.background)
    UINavigationBar.appearance().standardAppearance = navBarAppearance
    UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
}
```

### Date-based 计时器（锁屏后仍准确）
```swift
private var workoutStartTime: Date?

private func startTimer() {
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        guard let self = self, let startTime = self.workoutStartTime else { return }
        self.elapsedTime = Date().timeIntervalSince(startTime)
    }
}
```

---

## TODO & 里程碑

### P2 优化项
- [ ] 训练页增加组间休息计时
- [ ] 统计页增加周/月趋势图
- [ ] 数据导出功能（JSON）
- [ ] 训练提醒通知

### P3 增强项
- [ ] 目标设定与完成度追踪
- [ ] 进步趋势图表
- [ ] 热量消耗估算
- [ ] 动作视频指导

---

## 联系方式与备注

- 项目路径: `/Users/jerry/IOS_App/FitRock`
- Xcode项目: `FitRock.xcodeproj`
- 使用XcodeGen管理项目结构

**最后编译时间**: 2026-05-02
**编译状态**: BUILD SUCCEEDED