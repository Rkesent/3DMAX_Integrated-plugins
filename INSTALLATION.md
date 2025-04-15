# 3ds Max 贴图管理工具 - 安装指南

## 系统要求

- 3ds Max 2018或更高版本
- Python 3.x支持（3ds Max 2020及以上版本内置）
- 足够的磁盘空间用于贴图管理

## 安装步骤

### 方法一：手动安装

1. 下载以下文件：
   - `texture_manager.py`（主脚本文件）
   - `README.md`（使用文档）
   - `REQUIREMENTS.md`（开发需求文档）

2. 将`texture_manager.py`复制到以下目录：
   ```
   C:\Users\[用户名]\AppData\Local\Autodesk\3dsMax\[版本]\scripts\python
   ```
   > 注：替换[用户名]为您的Windows用户名，[版本]为您使用的3ds Max版本（如2022）

3. 在3ds Max中，打开MAXScript编辑器（按F11键）

4. 在编辑器中输入以下代码并运行：
   ```maxscript
   python.Execute "import texture_manager; texture_manager.run()"
   ```

### 方法二：创建启动脚本（推荐）

1. 将`texture_manager.py`复制到3ds Max脚本目录。

2. 创建一个名为`texture_manager_startup.ms`的新文件，内容如下：
   ```maxscript
   python.Execute "import texture_manager; texture_manager.run()"
   ```

3. 将该文件保存到以下目录：
   ```
   C:\Users\[用户名]\AppData\Local\Autodesk\3dsMax\[版本]\scripts\startup
   ```

4. 下次启动3ds Max时，贴图管理工具将自动加载。

### 方法三：创建宏按钮

1. 完成方法一中的步骤1-2。

2. 在3ds Max中，右键点击主工具栏，选择"自定义"。

3. 在"自定义"对话框中，切换到"工具栏"选项卡。

4. 点击"新建"按钮创建一个新的工具栏，命名为"贴图管理"。

5. 在"分类"下拉框中选择"MAXScript"。

6. 拖动"MAXScript"项到新创建的工具栏上。

7. 右键点击该按钮，选择"编辑按钮"。

8. 在弹出的对话框中输入以下脚本：
   ```maxscript
   python.Execute "import texture_manager; texture_manager.run()"
   ```

9. 点击"确定"保存设置。

10. 现在您可以通过点击工具栏上的按钮来启动贴图管理工具。

## 初次使用

1. 启动贴图管理工具后，将显示主界面。

2. 点击"检查贴图"按钮开始扫描场景中的贴图。

3. 所有发现的贴图将显示在左侧列表中。

4. 选择一个贴图可以在右侧查看其详细信息。

5. 使用底部的按钮执行各种贴图管理操作。

## 故障排除

### 常见问题

1. **脚本无法加载**
   - 确保Python支持已在3ds Max中启用
   - 检查脚本路径是否正确
   - 尝试重启3ds Max

2. **找不到贴图**
   - 确保贴图文件存在于指定路径
   - 检查文件权限
   - 尝试使用"更换路径"功能更新贴图路径

3. **UI控件不显示**
   - 检查3ds Max版本兼容性
   - 尝试重新加载脚本

### 联系支持

如果您遇到任何问题或有改进建议，请发送邮件至：[您的邮箱地址]

## 卸载方法

1. 从3ds Max脚本目录中删除`texture_manager.py`文件。

2. 如果使用了启动脚本，删除`texture_manager_startup.ms`文件。

3. 如果创建了宏按钮，打开"自定义"对话框删除相应的工具栏或按钮。 