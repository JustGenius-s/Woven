# 华为账号与云空间同步接入

## 当前代码状态

App 已包含华为账号标准登录按钮、账号状态检查、关系型数据库本地镜像、旧数据迁移、手动/自动云同步和失败降级。未完成 AppGallery Connect（AGC）配置时，App 会继续使用本地数据，并在设置页显示“服务尚未完成配置”。

`DeepSeek API Key` 明确排除在同步范围之外。当前同步的数据是：

- 五十音、语法、音乐、阅读、场景及旧旅程进度；
- 已学单词的稳定内容 ID；
- 单词对话与场景对练的消息记录。

## 发布前必须完成的外部配置

1. 在 AGC 创建或选择包名为 `com.justgenius.kotoba` 的 HarmonyOS 应用，并开通 Account Kit。
2. 配置调试和发布证书指纹。账号按钮会校验包签名，签名文件仍保存在仓库外。
3. 当前 AGC APP ID 与 Client ID 已按控制台信息写入工程；如果 AGC 侧重新生成凭据，需要同步更新 `entry/src/main/module.json5`：

   ```json5
   "metadata": [
     {
       "name": "app_id",
       "value": "6917615089465912527"
     },
     {
       "name": "client_id",
       "value": "6917615089465912527"
     }
   ]
   ```

4. 按华为“同应用端云数据同步”文档部署云侧环境，并建立与下表完全同名、同类型的云表字段。
5. 使用登录同一华为账号的真机完成最终同步验收。模拟器调试 Account Kit 时选择 `emulator + debug` 产品，并在 AGC 登记 Development 证书指纹；发布构建使用 `default + release`。

官方参考：[华为账号登录](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/account-quick-login-overview)、[同应用端云数据同步](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/data-cloud-sync-overview)。

## 云表结构

所有表均使用 `record_id` 作为文本主键。字段名必须与端侧 SQL 一致。

### `learning_progress`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `record_id` | Text | `<courseId>:progress:<kind>` |
| `course_id` | Text | 稳定课程 ID |
| `target_locale` | Text | 学习目标语言，BCP 47 |
| `support_locale` | Text | 讲解语言，BCP 47 |
| `kind` | Text | 进度类别 |
| `item_id` | Text | 当前内容稳定 ID |
| `numeric_value` | Integer | 索引、阶段或位掩码 |
| `text_value` | Text | 预留的非展示型状态值 |
| `updated_at` | Integer | 毫秒时间戳 |
| `deleted` | Integer | 0/1 逻辑删除标记 |

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

## 多语言约束

- `course_id` 是课程命名空间，例如当前课程为 `japanese-core-v1`；新增目标语言必须使用新的稳定课程 ID。
- `target_locale`、`support_locale` 和消息的 `language_tag` 使用 BCP 47，例如 `ja-JP`、`ko-KR`、`zh-Hans`。
- 云端只保存稳定内容 ID，不保存“单词释义”等可翻译展示文案。同步到设备后，由对应课程包和当前界面语言解析文案。
- 本地词汇与对话文件位于 `kotoba_learning/courses/<courseId>/`，不同语言课程不会互相覆盖；旧版未分课程的数据会作为当前日语课程迁移。
- 五十音、语法、音乐、阅读、场景和旅程进度也使用 `courseId` 命名空间保存；当前日语课程会透明回读旧版未分课程的 Preferences，其他课程从独立初始状态开始。
- 所有新增账号与同步界面文案都使用资源键。继续扩展 UI 语言时，为相同资源键添加地区资源，不要在同步记录里写本地化字符串。

## 端侧权限说明

当前工程声明 `ohos.permission.DISTRIBUTED_DATASYNC`，并配置了用途说明与 `EntryAbility` 使用场景。App 启动时只检查授权状态，不主动弹窗；用户登录账号或点击“立即同步”时才发起系统授权。拒绝授权不会影响本地学习，云同步状态会显示为“需要允许跨设备协同”。

## 合并与安全规则

- 普通“当前内容”以最近修改记录为准；旧旅程的完成位掩码使用按位合并，避免已完成阶段回退。
- 聊天消息使用 UUID，并按 `created_at` 排序，使不同设备新增的消息可以合并。
- 删除使用逻辑删除字段，为后续跨设备删除保留语义。
- 华为账号凭证只缓存 OpenID/UnionID 用于检查登录状态，不保存 Authorization Code、ID Token 或 Access Token。
- 如果以后接入业务服务端，Authorization Code 必须在服务端换取并校验令牌，不能把端侧返回值当作服务端身份认证结果。
