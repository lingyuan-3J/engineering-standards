# FastAPI 开发规范

适用于 FastAPI 项目，同时阅读 [Python 开发规范](02-Python开发规范.md)。数据库使用 SQLAlchemy AsyncSession 时同时阅读其规范，本文件不向 Django 项目强加 FastAPI 的接口和事务方式。

## 1 请求模型

Pydantic 模型显式定义可写字段、类型、必填性及边界。有限字符串集合采用 Literal 或项目已有的明确枚举；例如模式选择不接收任意字符串。实体类型、批量数量和具体业务字段由领域方案定义，不复制其他项目的业务枚举。

## 2 HTTP 状态

使用 `fastapi.status` 中的具名常量，HTTPException 使用具名参数，不在业务分支散布裸状态数字：

```python
from fastapi import HTTPException, status

raise HTTPException(
    status_code=status.HTTP_404_NOT_FOUND,
    detail="资源不存在",
)
```

HTTP 层使用 HTTPException 或已注册异常处理器表达失败，不使用泛化 Exception 代替明确接口错误。领域错误在 HTTP 边界映射，具体依据见 [FastAPI 错误处理文档](https://fastapi.tiangolo.com/tutorial/handling-errors/)。

## 3 错误响应

面向中文用户的接口提示使用可理解的中文文案，稳定错误码和响应结构按项目协议。第三方原始错误经脱敏后写入诊断日志，不将堆栈、密钥或渠道内部响应直接返回用户。

可处理的参数、类型和渠道异常分别映射；未预期异常由统一边界处理，不能返回空对象冒充成功。具体 Python 捕获方式见对应规范。

## 4 应用生命周期

启用能力的注册、配置校验、连接池创建和关闭由应用入口及 lifespan 明确管理，原则见通用启动初始化规范。需要异步初始化的资源在 lifespan 中 await，不能在路由或工厂第一次被调用时偷偷创建。

独立 worker 及后台任务入口各自初始化所需资源，不能依赖 Web 进程已完成初始化。

## 5 认证配置

自管密码哈希默认使用 scrypt 或经过明确评估的更强专用算法，参数及验证策略由项目确定；既有成熟认证框架遵循其已确认安全策略。JWT 签名密钥由环境或秘密设施提供，不能硬编码。

面向账户的 CORS 按实际前端来源设白名单，不用通配来源替代配置。认证、跨域、输入和日志原则见通用秘密管理规范。

## 6 异步数据库

采用异步应用和 AsyncSession 的业务 I/O 使用异步驱动，不能将同步数据库请求直接放进 async 路由阻塞事件循环。具体会话、提交和批量写入遵循 [SQLAlchemy 开发规范](04-SQLAlchemy开发规范.md)。
