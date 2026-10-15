# Python 开发规范

适用于 Python 工程，Django、FastAPI 等框架同时遵循其各自规范。可读性、注释内容、异常数据及启动职责见 [通用编码规范](../01-通用编码规范.md)，本文件维护 Python 表达方式。

## 1 类型注解

公共函数完整标注参数和返回类型，容器说明元素类型，例如 `list[str]`、`dict[str, Any]`，避免裸 list、dict。Any 仅用于实际允许不确定结构的边界，解析后转为明确类型。

固定字段优先使用已有类型模型，不为简单局部值另建类型。

返回异步流的接口使用 `AsyncIterator[T]` 或实际需要的 `AsyncGenerator`，不声明为同步 Iterator。普通 async 函数仍标注其实际结果类型。有限字符串集合使用 Literal 或项目已有的明确枚举，Pydantic 校验见 FastAPI 规范。

## 2 说明格式

### 2.1 定义说明

函数和类的整体说明使用中文 # 注释，放在 def、async def 或 class 的前一行，不在函数体或类体内写说明用 docstring。存在装饰器时，注释放在第一条装饰器上方；方法和嵌套函数同样处理。参数、返回值及特殊约束继续在定义上方说明，注释内容遵循通用规范。

```python
# 解析一条业务记录。
# 必需字段缺失或类型错误时抛出 RecordParseError。
def parse_record(raw_record: str) -> dict[str, str]:
    ...
```

框架需要在运行时读取工具、HTTP 或 JSON Schema 说明时，通过所属接口的 description 等参数显式提供，不依赖函数或类的 docstring。移动说明时保留实际可见的说明，检查继承关系，避免子类误用父类说明。

### 2.2 模块说明

Python 文件顶部说明统一写在一个多行模块 docstring 中，起始和结束三双引号各独占一行，正文置于其间；不拆成单行 docstring 和额外顶部注释。先概括模块作用，再按需要说明职责、流程和状态归属，不为凑行数添加内容。

```python
"""
提供记录解析功能。
校验必需字段并保留合法空值。
"""
from __future__ import annotations
```

模块 docstring 位于所有导入及 future 导入之前。新增文件和修改顶部说明时采用此格式，函数和类继续使用定义外注释。

## 3 分支表达

复杂取值、类型校验和递归过滤遵循通用可读性规则，例如：

```python
raw_text = record.get("text")
if isinstance(raw_text, str):
    record_text = raw_text
else:
    record_text = ""

child_texts: list[str] = []
for child_record in child_records:
    if not isinstance(child_record, dict):
        continue

    child_text = parse_child(child_record)
    if child_text:
        child_texts.append(child_text)
```

示例的 text 允许缺失，故显式使用空值；外部协议必需字段缺失须按通用异常数据规范报错，不能把此例当作所有解析的默认策略。

## 4 导入方式

使用正常 import，不用 `__import__` 拼装普通依赖，例如直接 `import datetime`。业务支持的能力用显式注册和清晰依赖维护，不通过延迟 import 为缺失的启动初始化兜底。

导入排序交给项目静态检查。动态加载仅用于明确的扩展发现需求，通过已有入口校验来源及允许范围；不得把用户或模型提供的任意字符串直接作为可执行导入路径。

## 5 异常处理

捕获确实能够处理的具体异常，避免裸 except、无处理的捕获再抛出，以及将所有异常统一转换为普通成功结果。需要转换错误时保留异常链，例如 `raise RecordParseError(...) from error`。

领域服务使用明确领域异常，HTTPException 由 HTTP 边界映射；后台任务、测试及其他入口可复用领域服务。第三方诊断信息脱敏留在日志，用户提示采用项目约定的可理解文案。

任务或进程最外层确需统一收尾时，可以捕获 Exception，但必须保留失败状态和可追踪原因。取消信号按取消流程传播，不吞掉后继续正常处理；资源通过上下文管理器或 finally 释放。错误语言及分类保留要求见通用说明语言规则。

## 6 自动化检查

提交 Python 改动前运行当前项目的测试和静态检查。采用 pytest、Ruff 的工程可使用 `python -m pytest -q` 和项目实际配置的 `ruff check <源码目录> <测试目录>`；目录及工具版本由项目确定。

解析、计数、访问校验和事务变更的测试范围遵循通用验证规则，不能因函数没有 HTTP 入口就省略错误输入验证。

## 7 独立赋值

多个变量各自计算时，每个变量使用一条赋值语句，不用逗号合并多次独立赋值。真正的结构解包按其语义处理。拆分保持原有求值顺序；后续表达式需要赋值前的旧值时，先用中间变量保存。

## 8 函数组织

普通辅助函数默认定义在模块层，依赖对象通过参数传入。仅在回调确需共享或修改外层局部状态时保留内部函数，并在定义上方说明依赖状态和保留原因。仅在一处调用不构成内部定义的理由。

函数默认使用普通参数，允许按位置或名称调用。不无必要地用单独的 `*` 强制关键字参数；仅框架接口要求或存在明确调用约束时采用，并说明原因。调用处可以主动写参数名以表达用途。
