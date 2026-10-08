# 华为账号与云空间同步

应用已接华为账号标准登录、本地数据库镜像，以及手动和自动云同步。AppGallery Connect（AGC）未配好时继续使用本地数据，设置页显示「服务尚未完成配置」。

同步范围是学习进度、已学单词的稳定 ID，以及单词对话和场景对练的消息。DeepSeek、MiniMax 和火山语音的 API Key 不同步。

官方文档：[华为账号登录](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/account-quick-login-overview)、[同应用端云数据同步](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/data-cloud-sync-overview)。

## 发布前配置

1. 在 AGC 选择包名 `com.justgenius.kotoba` 的 HarmonyOS 应用，并开通 Account Kit。
2. 登记证书指纹。模拟器调试用 `emulator + debug`，发布包用 `default + release`。签名文件不在仓库中。
3. 凭据变更时，同步更新 `entry/src/main/module.json5` 的 `app_id` 和 `client_id`。当前值都是 `6917615089465912527`。
4. 按「同应用端云数据同步」部署云侧，并建立下面同名、同类型的表。
5. 用登录同一华为账号的真机做最终验收。

## 云表

所有表以文本字段 `record_id` 为主键。字段名必须和端侧 SQL 一致。

### `learning_progress`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `record_id` | Text | `<courseId>:progress:<kind>` |
| `course_id` | Text | 稳定课程 ID |
| `target_locale` | Text | 学习目标语言，BCP 47 |
| `support_locale` | Text | 讲解语言，BCP 47 |
| `kind` | Text | 进度类别 |
| `item_id` | Text | 当前内容的稳定 ID |
| `numeric_value` | Integer | 索引、阶段或位掩码 |
| `text_value` | Text | 预留的非展示状态 |
| `updated_at` | Integer | 毫秒时间戳 |
| `deleted` | Integer | `0` / `1` 逻辑删除 |

### `learned_item`

| 字段 | 类型 |
| --- | --- |
| `record_id` | Text |
| `course_id` | Text |
| `target_locale` | Text |
| `item_type` | Text |
| `item_id` | Text |
| `level` | Text |
| `learned_at` | Integer |
| `updated_at` | Integer |
| `deleted` | Integer |

### `conversation`

| 字段 | 类型 |
| --- | --- |
| `record_id` | Text |
| `course_id` | Text |
| `target_locale` | Text |
| `support_locale` | Text |
| `topic_type` | Text |
| `topic_id` | Text |
| `updated_at` | Integer |
| `deleted` | Integer |

### `message`

| 字段 | 类型 |
| --- | --- |
| `record_id` | Text |
| `conversation_id` | Text |
| `course_id` | Text |
| `target_locale` | Text |
| `role` | Text |
| `body` | Text |
| `language_tag` | Text |
| `created_at` | Integer |
| `revision` | Integer |
| `updated_at` | Integer |
| `deleted` | Integer |

## 约定

- `course_id` 是课程命名空间。当前日语课程是 `japanese-core-v1`。新的目标语言使用新的课程 ID。
- `target_locale`、`support_locale` 和 `language_tag` 使用 BCP 47，例如 `ja-JP`、`zh-Hans`。
- 云端只存稳定内容 ID，不存可翻译文案。设备用课程包和界面语言解析文案。
- 本地课程文件在 `kotoba_learning/courses/<courseId>/`。旧的未分课程数据会迁到当前日语课程。
- 界面文案使用资源键。扩展语言时加地区资源，不要把本地化字符串写入同步记录。
- 工程声明了 `ohos.permission.DISTRIBUTED_DATASYNC`。启动时只检查授权；登录或点「立即同步」时才请求。拒绝后本地学习不受影响。
- 普通记录以最近修改为准。旧旅程的完成位掩码按位合并，避免已完成阶段回退。消息用 UUID，按 `created_at` 合并。删除是逻辑删除。
- 本机只缓存 OpenID / UnionID 用来判断登录状态，不保存 Authorization Code、ID Token 或 Access Token。
