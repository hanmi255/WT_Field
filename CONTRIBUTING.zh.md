# 贡献指南

> English version: [CONTRIBUTING.md](CONTRIBUTING.md)

## 开始之前

这个仓库是一个 Godot 项目.

当前基线：

- Godot `4.6`
- 已启用 `.NET`
- 主场景：`scenes/game.tscn`
- 运行时代码位于 `scripts/`

这里的大多数提交通常属于以下几类：

- `scripts/` 中的玩法脚本
- `scenes/` 中的场景调整
- `assets/` 中的美术、音频和字体资源
- `project.godot` 中的项目配置修改

## 仓库结构

- `project.godot`：项目配置、渲染设置、输入映射和启动场景
- `scenes/`：可运行场景和场景组合
- `scripts/`：GDScript 运行时逻辑
- `assets/texture/`：贴图和精灵图集
- `assets/audio/`：音乐和音效
- `assets/font/`：字体资源

## 规则 1：保持改动原子性

每个 commit 或 PR 都应该只包含一个清晰、连贯的改动。

好的例子：

- 一个玩法 bug 修复
- 一个移动或动画表现调整
- 一个场景连线修复
- 一个资源导入设置修正
- 一个针对特定功能的输入映射更新

不要把无关的场景改动、配置抖动和玩法逻辑修改混在同一个 commit 里，除非它们确实共同构成同一个功能。

## 规则 2：正确提交 Godot 资源

Godot 项目依赖稳定的场景路径、资源引用和 UID。

- 提交脚本或场景时，一并提交对应的 `.uid` 文件
- 不要随意删除并重新生成 `.uid` 文件
- 如果你重命名或移动了场景、脚本，确认依赖引用仍然可以正确解析
- 当资源导入设置被有意修改时，提交对应的 `.import` 文件
- 如果资源只是因为编辑器重新导入而变化、但没有实际项目意义，请在暂存前仔细检查

当前仓库级忽略规则包括：

- `.godot/`
- `android/`
- `.vscode/`

这意味着许多本地或意外改动仍然会出现在 Git 里，因此必须选择性暂存。

## 规则 3：谨慎修改项目配置

把 `project.godot` 视为高风险文件。

- 输入映射的修改必须是有意的，并认真复查
- 避免顺手带上无关的渲染、窗口或物理设置变更
- 如果修改了启动场景，请说明原因
- 能通过 Godot 编辑器安全完成的配置修改，不要随意手写配置

## 规则 4：遵循现有代码模式

- 遵循当前脚本区域已经存在的写法风格
- 优先写清晰直接的 GDScript，不要引入没必要的抽象
- 修 warning 或做清理时，尽量保持行为不变
- 只有在确实能节省阅读成本时再添加注释

## 验证

在声明工作完成之前，请执行真正适用于 Godot 项目的检查：

1. 用 Godot `4.6` 打开项目
2. 确认编辑器完成资源导入和脚本解析
3. 检查错误面板、调试器和输出窗口里是否出现新的问题
4. 打开受影响的场景、脚本或资源，确认引用没有断掉
5. 视情况运行相关场景，或直接运行主场景，验证改动行为

推荐的本地验证目标：

- 项目能干净加载，没有新的脚本解析错误
- 当改动影响玩法时，运行 `scenes/game.tscn`
- 打开被修改的场景，确认节点路径和导出引用正常
- 直接在编辑器运行时验证移动、动画、碰撞或子弹行为

不要把外部编辑器的 lint 结果当作项目健康的唯一依据。

## 场景、脚本和资源改动

- 保持 `.tscn` diff 尽量小，避免打开并保存无关场景
- 重组场景时，保留节点路径和导出引用
- 如果修改了共享资源的导入设置，要在受影响场景里确认视觉或音频结果
- 修改被场景引用的脚本后，要确认场景仍能正常实例化和运行

## Commit Message

请使用清晰的英文 commit message。推荐格式为 `<type>: <subject>`。

示例：

- `fix: prevent bullet from surviving wall collisions`
- `fix: keep player facing animation in sync`
- `feat: add bullet scene setup`
- `refactor: simplify player movement animation update`

保持提交原子化，并选择性暂存文件。对这个仓库来说，`git add .` 通常不是个好主意。

允许并鼓励使用 AI 参与的提交方式，只要这符合你的工作流，并且你希望保留对应的贡献记录。

- 如果你希望 Claude、Codex 等 AI 在 git 历史或 GitHub Contributors 归属中出现，请直接使用对应 bot 或服务身份作为 git author
- 如果某次 commit 由 AI Agent 完成，那么该 commit message 中必须包含对应 Agent 身份的 `Co-authored-by:` trailer
- 只在 commit subject 里写 `claude` 或 `codex`，通常并不会让它们出现在 GitHub Contributors 中
- 如果要使用 AI 身份提交，请在 commit 前确认 author name 和 author email 已正确配置到该身份

示例：

```text
Co-authored-by: Codex <codex@example.com>
```
