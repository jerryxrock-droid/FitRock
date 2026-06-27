# FitRock 健身训练 App

## 基本信息
- **平台**: iOS 16+
- **UI**: 中文, 深色主题 (Material Design)
- **技术栈**: SwiftUI + SQLite (Swift Package)

## Tab 结构 (4 Tab)
1. **日历** (HomeView) — 训练日历/历史
2. **训练** (RecordView) — 记录训练、动作搜索
3. **动作库** (ExerciseLibraryView) — 双模式：按肌肉 / 按器械
4. **统计** (StatsView) — 训练统计/图表

## 双模式动作库 (v2025-06-27+)

### 肌肉模式 (DB)
- 从 SQLite `exercises` 表加载
- MuscleMap 交互人体图谱选择肌群
- 教学内容来自 `ExerciseTeachingData.swift`

### 器械模式 (JSON)
- 从本地 JSON 数据加载，注册在 Xcode Resources
- 20 个健身房器械（中文名称 + 描述 + 调节方法 + 安全提示）
- `FlowLayout` 标签式展示目标肌群
- 26 个关联训练动作（含步骤 + 常见错误）

### 数据服务
- `LocalExerciseDataService` — 单例，从 Bundle 加载 JSON
- `equipments.json` — 20 个器械数据
- `exercises.json` — 26 个训练动作（关联到器械）
- `muscle_zh_map.json` — 肌肉名中英文映射

### 图片加载
- 52 张训练动作图（JPG），打包到 `ExerciseImages/` bundle 目录
- `AsyncExerciseImageView` — 从 Bundle 异步加载，开发环境回退到本地路径
- 图片来自 [free-exercise-db](https://github.com/yuhonas/free-exercise-db)

## JSON 关联示意图
```
equipments.json ──exerciseIds──▶ exercises.json
     │                                │
     │ equipmentId                    │ images[]
     ▼                                ▼
EquipmentDetailView            ExerciseDetailView
  ├ 器械信息                      ├ 图片(Async加载)
  ├ 目标/辅助肌群 ──FlowLayout──▶  ├ 主练/辅助肌群
  ├ 使用前调节                      ├ 所需器械 ──▶ EquipmentDetailView
  ├ 安全提示                        ├ 动作步骤
  └ 相关动作列表                    └ 常见错误
```

## 核心数据模型
- DB 系: `Exercise` (含 unit), `Workout`, `WorkoutExercise`, `ExerciseSet`
- 模板系: `WorkoutTemplate`, `WorkoutTemplateExercise`, `WorkoutTemplateSet`
- 纪录系: `PersonalRecord`, `PersonalRecordEvent`
- JSON 系: `Equipment` (20 件), `ExerciseInfo` (26 个)

## 核心服务
- `DatabaseManager` — SQLite 单例
- `LocalExerciseDataService` — JSON 数据单例
- `PRService` — 个人记录评估
- `HapticManager` — 触觉反馈

## 文件结构 (新增部分)
```
FitRock/
├── Core/
│   ├── Models/
│   │   ├── Equipment.swift       # 器械模型
│   │   └── ExerciseInfo.swift    # JSON动作模型
│   └── Services/
│       └── LocalExerciseDataService.swift  # JSON数据加载
├── Features/ExerciseLibrary/
│   ├── EquipmentDetailView.swift  # 器械详情页
│   ├── ExerciseDetailView.swift   # 动作详情(双模式)
│   ├── ExerciseLibraryView.swift  # 动作库(双模式切换)
│   └── ExerciseLibraryViewModel.swift
├── Shared/
│   ├── FlowLayout.swift           # 标签环绕布局
│   └── AsyncExerciseImageView.swift  # 异步图片加载
└── Resources/
    ├── Data/                      # JSON数据(equipments/exercises/muscle_zh_map)
    └── ExerciseImages/            # 52张训练动作图(24个目录)
```

## 开发规范
- 提交添加日期版本标签 `vYYYY-MM-DD`
- JSON 数据优先从 Bundle 加载（正式构建），本地路径仅开发回退
- 新器械/动作：更新 JSON + 添加对应图片到 ExerciseImages/
