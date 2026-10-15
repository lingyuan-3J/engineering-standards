# SQLAlchemy 开发规范

适用于采用 SQLAlchemy AsyncSession 的异步工程。它不改变 Django 等其他 ORM 的同步用法；类型和异常表达遵循 [Python 开发规范](02-Python开发规范.md)。

## 1 会话生命周期

AsyncSession 是工作单元和事务上下文，不是数据库本身。请求或独立任务拥有自己的会话，按上下文释放；并行任务不共享同一个可变会话，不将请求会话继续交给已脱离请求生命周期的后台任务。

需要读取和修改业务数据的服务可以接收会话，以便组合在同一事务中。只为写运行日志或指标而给无关 Gateway、Provider 增加业务 session 参数，应改为独立观测能力。

连接、Session 和事务在允许的执行范围内创建、使用及关闭，不跨线程传递不允许跨线程使用的会话。异步路径中的长时间阻塞操作交给合适执行线程或已有异步接口，不仅套一层 async def。

## 2 事务所有权

最外层业务用例持有完整事务的提交和回滚职责，具体落在编排 service 还是 Router 由项目架构确定。被调用的查询、修改及 helper 不擅自 commit 或 rollback 调用方会话；需要落库约束或取得生成值时按需要 flush，由外层决定最终结果。

一个完整用例内的多步数据库修改用显式事务组织，异常使整个用例回滚，不在循环中逐条提交。不能因为中间层需要记日志就提交调用方尚未完成的其他修改。

业务明确分批完成时说明各批边界和失败语义。避免持有事务等待人工决定或长时间网络请求。

## 3 显式事务

在会话持有方组织单个事务，例如：

```python
async with session_factory() as session:
    async with session.begin():
        await update_record(session, record_id, title)
        await append_business_audit(session, record_id)
```

上述 begin 上下文成功退出时提交，异常时回滚；内部服务不再 commit。应在开始相关读写前确定事务边界，已有自动开始的事务时由会话持有方统一管理，不随意再套一个顶层 begin。

`begin_nested()` 是 SAVEPOINT，需要隔离局部失败时才使用，不能当作所有复杂操作的默认事务，也不代表外层已提交。SQLAlchemy 的 `commit()` 作用于最外层事务，内部释放 SAVEPOINT 不应提交整个调用方用例。语义参见 [SQLAlchemy 事务文档](https://docs.sqlalchemy.org/en/20/orm/session_transaction.html#using-savepoint)。

## 4 观测隔离

AI 调用日志、指标等与业务原子性无关的观测数据，使用其持有方创建的独立会话或可靠写入机制，不接收业务 session 仅为内部提交日志。它们的失败不能提交、回滚或覆盖业务结果，应独立报告和处理。

必须和业务同时成立的操作审计、资金流水及业务状态，使用业务会话在同一事务提交。独立观测和业务审计按通用运行日志规范及领域契约判断，不能将“审计”一律改成独立事务。

独立观测复用已有日志入口或会话工厂，不为每个模块另建一套。观测失败按所属策略处理，不无意改变业务提交结果。

## 5 批量写入

先校验批次输入和数量，再批量添加或执行明确的批量操作，在所属用例事务统一提交。避免每条记录单独 commit，保持关联顺序、生成 ID、数据库约束和失败回滚语义。批量上限由领域方案定义，不强制所有业务使用固定值。

`add()`、`add_all()` 等会话内操作不机械加 await；execute、flush、commit 及对应异步 I/O 按 API 契约 await。异步会话及并发原则见 [SQLAlchemy asyncio 文档](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html#using-asyncsession-with-concurrent-tasks)。

## 6 事务验证

验证被调函数不会提交外层未完成数据，多步骤失败完整回滚，独立观测失败不污染业务会话，以及业务审计失败按契约回滚。SAVEPOINT 和后台任务各自覆盖实际边界，不以函数名字判定其是否拥有事务。

## 7 数据访问

在本规范适用的 AsyncSession 工程中统一声明表模型，普通记录读写使用 ORM 对象及会话。聚合、批量、原子递增和带版本条件的状态更新可以使用 SQLAlchemy 表达式，仍加入同一会话和事务。不仅替换 SQL 文本而继续维护一套普通读写的表名、列名和行结果转换接口。
