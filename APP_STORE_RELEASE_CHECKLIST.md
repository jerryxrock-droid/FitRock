# FitRock App Store 上架检查清单

## P0 - 提审前必须完成
- 隐私政策：使用 `PRIVACY_POLICY_DRAFT.md` 作为基础，发布到可公开访问的 URL，并填入 App Store Connect。
- App Privacy：按当前实现声明无追踪、无第三方广告、不上传训练或健康数据；如未来加入云同步/分析 SDK，必须重新填写。
- HealthKit：确认权限文案与实际读取范围一致：体重、心率、静息心率、活动能量；HealthKit 授权必须保持可选。
- 免责声明：设置页必须能看到“训练免责声明”，训练计划不得表述为医疗建议。
- 真机回归：至少覆盖 iPhone 小屏/大屏、中文系统、深色模式、首次启动、训练记录、后台恢复、删除训练、计划生成、HealthKit 拒绝授权。
- 数据安全：确认正式包不会传入 `--ui-testing`、`--reset-ui-data`、`--reset-onboarding` 等测试启动参数。
- 资源完整性：运行资源测试，确保 JSON、图片和动作库详情无缺失。

## P1 - 首版体验建议
- App Store 截图重点展示：快速记录、动作库/器械教学、肌肉热力图、周训练池、日历历史。
- App Review Notes 说明：HealthKit 是可选增强；无授权也可以完整记录训练和使用计划。
- 商店定位建议：本地优先的力量训练记录、肌肉热力图、灵活周训练池。
- 首次使用路径：确认新手引导 30 秒内能进入第一条真实训练。

## 本地验证命令
```bash
xcodebuild build-for-testing -project FitRock.xcodeproj -scheme FitRock -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project FitRock.xcodeproj -scheme FitRock -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FitRockTests
xcodebuild test -project FitRock.xcodeproj -scheme FitRock -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FitRockUITests
```
