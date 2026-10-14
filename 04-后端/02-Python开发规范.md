# Python 开发规范

适用于 Python 工程，Django、FastAPI 等框架同时遵循其各自规范。可读性、注释内容、异常数据及启动职责见 [通用编码规范](../01-通用编码规范.md)，本文件维护 Python 表达方式。

## 1 类型注解

公共函数完整标注参数和返回类型，容器说明元素类型，例如 `list[str]`、`dict[str, Any]`，避免裸 list、dict。Any 仅用于实际允许不确定结构的边界，解析后转为明确类型。

返回异步流的接口使用 `AsyncIterator[T]` 或实际需要的 `AsyncGenerator`，不声明为同步 Iterator。普通 async 函数仍标注其实际结果类型。有限字符串集合使用 Literal 或项目已有的明确枚举，Pydantic 校验见 FastAPI 规范。

## 2 Docstring

公共函数、类和模块简要说明契约；抽象方法及 Pydantic 模型按实际需要说明特殊约束。单行 docstring 保持单行，多行格式如下：

```python
def parse_record(raw_record: str) -> dict[str, str]:
    """
    解析一条业务记录。

    记录缺少必需字段或字段类型错误时抛出 RecordParseError。
    """
    ...
```

多行的起始三引号后换行，标题独占一行，标题和正文之间空一行，结束三引号独占一行。结束引号前的空行可有可无；不能把正文或字面转义的换行符挤在三引号同一行。上述为本仓库格式约定，不声明为外部风格标准的原文。

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

## 5 异常处理

捕获确实能够处理的具体异常，避免裸 except、无处理的捕获再抛出，以及将所有异常统一转换为普通成功结果。需要转换错误时保留异常链，例如 `raise RecordParseError(...) from error`。

领域服务使用明确领域异常，HTTPException 由 HTTP 边界映射；后台任务、测试及其他入口可复用领域服务。第三方诊断信息脱敏留在日志，用户提示采用项目约定的可理解文案。

## 6 自动化检查

提交 Python 改动前运行当前项目的测试和静态检查。采用 pytest、Ruff 的工程可使用 `python -m pytest -q` 和项目实际配置的 `ruff check <源码目录> <测试目录>`；目录及工具版本由项目确定。

解析、计数、访问校验和事务变更的测试范围遵循通用验证规则，不能因函数没有 HTTP 入口就省略错误输入验证。
