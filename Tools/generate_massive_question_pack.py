#!/usr/bin/env python3

import json
from pathlib import Path


DEFINITION_STEMS = [
    "关于{term}，下列说法正确的是：",
    "下列关于{term}的描述中，正确的是：",
    "从系统设计角度看，{term}通常表示：",
    "对于{term}的理解，正确的是：",
]

PURPOSE_STEMS = [
    "引入{term}的主要目的是：",
    "在系统中使用{term}，通常是为了：",
    "关于{term}的典型价值，下列说法正确的是：",
    "采用{term}方案，最主要带来的收益通常是：",
]

SCENARIO_STEMS = [
    "{scenario}，最合适的做法是：",
    "当需要{scenario}时，应优先考虑：",
    "为了解决“{scenario}”这类问题，通常采用：",
    "在实际项目中，如果想做到“{scenario}”，较合理的方案是：",
]

YEARS = [2025, 2024, 2023, 2022, 2021, 2020]
OPTION_LABELS = ["A", "B", "C", "D"]


DEFINITION_BANK = [
    {
        "category": "计算机系统基础",
        "knowledge_points": ["流水线", "CPU"],
        "term": "指令流水线",
        "correct": "通过多个阶段重叠执行提升指令吞吐效率",
        "wrongs": ["只适合图像压缩", "会取消寄存器使用", "一定降低并发能力"],
        "analysis": "流水线通过分阶段重叠执行提升吞吐量，但也会引入冒险和停顿问题。",
    },
    {
        "category": "计算机系统基础",
        "knowledge_points": ["DMA", "I/O"],
        "term": "DMA",
        "correct": "由外设和内存直接交换数据，减少 CPU 干预",
        "wrongs": ["替代所有中断机制", "只用于加密处理", "等同于缓存一致性协议"],
        "analysis": "DMA 的核心是提高 I/O 传输效率，减少 CPU 在数据搬运上的参与。",
    },
    {
        "category": "操作系统",
        "knowledge_points": ["死锁", "资源管理"],
        "term": "死锁预防",
        "correct": "通过破坏死锁必要条件之一来避免死锁发生",
        "wrongs": ["在死锁发生后再回滚", "只用于数据库分库", "等同于页置换算法"],
        "analysis": "死锁预防和死锁避免不同，前者是从条件层面直接破坏死锁成立前提。",
    },
    {
        "category": "操作系统",
        "knowledge_points": ["线程", "进程"],
        "term": "线程",
        "correct": "是进程内可独立调度执行的基本单位",
        "wrongs": ["拥有独立地址空间且与进程无关", "只能用于单核 CPU", "不共享进程资源"],
        "analysis": "线程通常共享所属进程资源，但调度和执行粒度更轻量。",
    },
    {
        "category": "网络",
        "knowledge_points": ["TCP", "三次握手"],
        "term": "TCP 三次握手",
        "correct": "用于建立可靠连接并确认双方收发能力",
        "wrongs": ["用于释放连接", "只负责报文加密", "等同于 DNS 查询流程"],
        "analysis": "三次握手重点在建立可靠连接和同步序号，不是断开连接过程。",
    },
    {
        "category": "网络",
        "knowledge_points": ["路由", "OSI"],
        "term": "路由器",
        "correct": "主要根据网络层地址进行路径转发",
        "wrongs": ["只处理应用层数据", "只能用于串口设备", "不能连接不同网络"],
        "analysis": "路由器工作在网络层，是网络互联和路径选择的关键设备。",
    },
    {
        "category": "数据库",
        "knowledge_points": ["范式", "函数依赖"],
        "term": "第三范式",
        "correct": "要求消除非主属性对候选键的传递依赖",
        "wrongs": ["要求取消主键", "只适用于 NoSQL", "专门提升图片加载速度"],
        "analysis": "第三范式主要解决数据冗余和更新异常问题，是数据库设计基础。",
    },
    {
        "category": "数据库",
        "knowledge_points": ["事务", "隔离级别"],
        "term": "可重复读",
        "correct": "强调同一事务内多次读取同一数据时结果应保持一致",
        "wrongs": ["一定消除所有幻读", "等同于串行化", "主要用于备份恢复"],
        "analysis": "可重复读聚焦不可重复读问题，不同数据库对幻读处理方式可能不同。",
    },
    {
        "category": "软件工程",
        "knowledge_points": ["可行性分析", "项目立项"],
        "term": "技术可行性分析",
        "correct": "评估现有技术条件能否支撑系统建设目标",
        "wrongs": ["只评估 UI 美观程度", "只关注合同条款", "只在项目验收后进行"],
        "analysis": "可行性分析常分为技术、经济、操作等维度，技术可行性是立项基础之一。",
    },
    {
        "category": "软件工程",
        "knowledge_points": ["需求规格说明书", "需求分析"],
        "term": "需求规格说明书",
        "correct": "用于系统化描述功能、约束和质量要求",
        "wrongs": ["等同于代码实现", "只记录测试结果", "仅在运维阶段使用"],
        "analysis": "需求规格说明书是需求沟通、设计和测试的重要依据。",
    },
    {
        "category": "软件工程",
        "knowledge_points": ["单元测试", "测试层次"],
        "term": "单元测试",
        "correct": "主要验证模块或函数等最小可测试单元的正确性",
        "wrongs": ["只由用户执行", "专门用于验收合同", "等同于系统测试"],
        "analysis": "单元测试强调最小粒度验证，越早发现问题，修复成本越低。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["中介者模式", "设计模式"],
        "term": "中介者模式",
        "correct": "通过中介对象协调多个对象之间的交互关系",
        "wrongs": ["专门负责对象深拷贝", "只用于数据库设计", "等同于工厂模式"],
        "analysis": "中介者模式用于降低对象间直接耦合，集中管理交互逻辑。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["模板方法", "设计模式"],
        "term": "模板方法模式",
        "correct": "在父类中定义算法骨架，在子类中实现具体步骤",
        "wrongs": ["只用于缓存路由", "等同于观察者模式", "取消继承体系"],
        "analysis": "模板方法适合固定流程但局部步骤可扩展的场景。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["聚合", "DDD"],
        "term": "聚合根",
        "correct": "作为聚合对外访问的一致性边界入口",
        "wrongs": ["等同于数据库主库", "只表示日志入口", "用于负载均衡转发"],
        "analysis": "DDD 中聚合根控制内部对象访问和一致性规则，是建模核心概念。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["分层架构", "职责边界"],
        "term": "分层架构",
        "correct": "通过职责拆分减少变化影响并提升可维护性",
        "wrongs": ["保证系统没有性能瓶颈", "要求全部模块部署在单机", "取消接口抽象"],
        "analysis": "分层不是万能性能方案，但对职责清晰和维护性很有帮助。",
    },
    {
        "category": "系统安全",
        "knowledge_points": ["机密性", "完整性"],
        "term": "机密性",
        "correct": "确保信息只被授权对象访问和读取",
        "wrongs": ["保证服务永不宕机", "表示系统一定高性能", "等同于压缩比"],
        "analysis": "机密性、完整性、可用性是经典安全目标，机密性关注防止未授权泄露。",
    },
    {
        "category": "系统安全",
        "knowledge_points": ["AES", "对称加密"],
        "term": "对称加密",
        "correct": "加密和解密通常使用同一密钥或等效密钥",
        "wrongs": ["必须公开私钥", "只适用于数字签名", "等同于哈希函数"],
        "analysis": "对称加密常用于高效数据加密，但密钥分发是难点。",
    },
    {
        "category": "系统安全",
        "knowledge_points": ["哈希", "完整性校验"],
        "term": "哈希函数",
        "correct": "常用于生成摘要以支持完整性校验",
        "wrongs": ["专门用于双机热备", "保证通信机密性", "等同于数字证书"],
        "analysis": "哈希值常用于校验内容是否被篡改，不直接提供机密性。",
    },
    {
        "category": "新兴技术",
        "knowledge_points": ["RPA", "流程自动化"],
        "term": "RPA",
        "correct": "通过软件机器人自动执行规则明确的重复操作",
        "wrongs": ["等同于数据库事务", "只用于 GPU 训练", "取消流程建模"],
        "analysis": "RPA 适合规则清晰、重复性高的流程自动化场景。",
    },
    {
        "category": "新兴技术",
        "knowledge_points": ["联邦学习", "隐私计算"],
        "term": "联邦学习",
        "correct": "在不集中原始数据的前提下进行协同建模",
        "wrongs": ["要求先汇总全部原始数据", "只适用于 DNS 服务", "等同于区块链存储"],
        "analysis": "联邦学习强调数据不出域，适合隐私敏感的跨机构协作场景。",
    },
    {
        "category": "新兴技术",
        "knowledge_points": ["AIOps", "智能运维"],
        "term": "AIOps",
        "correct": "通过智能分析增强运维监控、告警和故障定位能力",
        "wrongs": ["替代所有研发流程", "只做手工测试", "专门负责域名解析"],
        "analysis": "AIOps 是运维治理升级方向，强调数据驱动的智能运维能力。",
    },
    {
        "category": "专业英语",
        "knowledge_points": ["latency", "专业英语"],
        "term": "latency",
        "correct": "通常表示时延或延迟",
        "wrongs": ["吞吐量", "可靠性", "扩展性"],
        "analysis": "专业英语题是稳拿分项，latency 对应的是系统响应延迟。",
    },
    {
        "category": "专业英语",
        "knowledge_points": ["availability", "专业英语"],
        "term": "availability",
        "correct": "通常表示可用性",
        "wrongs": ["完整性", "吞吐量", "可测试性"],
        "analysis": "availability 常出现在质量属性和高可用场景中。",
    },
    {
        "category": "专业英语",
        "knowledge_points": ["scalability", "专业英语"],
        "term": "scalability",
        "correct": "通常表示系统的可扩展性",
        "wrongs": ["压缩率", "认证能力", "一致性哈希"],
        "analysis": "专业英语和质量属性经常结合考察，scalability 是高频词。",
    },
    {
        "category": "项目管理",
        "knowledge_points": ["关键路径", "进度管理"],
        "term": "关键路径",
        "correct": "决定项目最短工期的活动路径",
        "wrongs": ["只表示预算上限", "专门用于缺陷统计", "等同于风险矩阵"],
        "analysis": "关键路径法是进度管理经典考点，常与工期计算题结合。",
    },
    {
        "category": "项目管理",
        "knowledge_points": ["风险登记册", "风险管理"],
        "term": "风险登记册",
        "correct": "用于记录和跟踪项目风险及应对措施",
        "wrongs": ["只记录代码提交", "专门保存 UI 设计稿", "等同于测试报告"],
        "analysis": "项目管理题中，风险识别、分析和跟踪工具很常见。",
    },
    {
        "category": "云原生",
        "knowledge_points": ["容器编排", "Kubernetes"],
        "term": "Pod",
        "correct": "是 Kubernetes 中可部署的最小工作单元",
        "wrongs": ["等同于节点操作系统", "只表示持久化卷", "专门负责日志聚合"],
        "analysis": "云原生基础题经常考 Kubernetes 核心概念和职责边界。",
    },
    {
        "category": "云原生",
        "knowledge_points": ["Ingress", "流量接入"],
        "term": "Ingress",
        "correct": "通常用于管理集群外部访问集群服务的入口规则",
        "wrongs": ["只负责 GPU 调度", "替代容器镜像", "等同于数据库索引"],
        "analysis": "Ingress 是云原生接入层高频概念，常与 Service 区分考察。",
    },
    {
        "category": "分布式",
        "knowledge_points": ["一致性", "CAP"],
        "term": "CAP 理论",
        "correct": "说明分布式系统在一致性、可用性和分区容忍性之间存在权衡",
        "wrongs": ["要求系统同时绝对满足三者", "只用于前端渲染", "等同于 ACID"],
        "analysis": "CAP 是分布式系统基础理论，题目常考其权衡思想而非死记字母。",
    },
    {
        "category": "分布式",
        "knowledge_points": ["脑裂", "高可用"],
        "term": "脑裂",
        "correct": "通常指集群分区后多个节点都认为自己是主节点的异常状态",
        "wrongs": ["表示数据库索引失效", "等同于缓存穿透", "只发生在前端框架中"],
        "analysis": "脑裂是高可用集群的重要故障模式，常与仲裁机制一起考。",
    },
]


PURPOSE_BANK = [
    {
        "category": "计算机系统基础",
        "knowledge_points": ["缓存", "性能优化"],
        "term": "多级缓存",
        "correct": "在成本和性能之间平衡不同层级存储访问速度",
        "wrongs": ["彻底消除主存", "替代进程调度", "只用于网络加密"],
        "analysis": "多级缓存设计的核心是在容量、成本和速度之间做层级平衡。",
    },
    {
        "category": "操作系统",
        "knowledge_points": ["时间片轮转", "调度算法"],
        "term": "时间片轮转调度",
        "correct": "提升交互式系统的响应公平性",
        "wrongs": ["保证所有作业零等待", "取消上下文切换", "只适用于批处理系统"],
        "analysis": "时间片轮转强调公平与响应性，但上下文切换成本也要考虑。",
    },
    {
        "category": "网络",
        "knowledge_points": ["NAT", "地址转换"],
        "term": "NAT",
        "correct": "实现私有地址与公网访问之间的地址映射",
        "wrongs": ["加速 CPU 运算", "替代 TLS 证书", "只做数据库主从复制"],
        "analysis": "NAT 主要用于地址复用和网络隔离场景，是网络基础高频点。",
    },
    {
        "category": "网络",
        "knowledge_points": ["VPN", "远程接入"],
        "term": "VPN",
        "correct": "在公共网络上构建安全的逻辑专用通信通道",
        "wrongs": ["替代数据库索引", "负责系统编译", "只用于本地缓存"],
        "analysis": "VPN 常用于远程办公和跨地域安全互联场景。",
    },
    {
        "category": "数据库",
        "knowledge_points": ["索引", "查询优化"],
        "term": "数据库索引",
        "correct": "减少数据定位范围，提高查询效率",
        "wrongs": ["取消表结构设计", "保证系统永不锁表", "替代事务机制"],
        "analysis": "索引提升查询性能，但会增加维护成本和写入开销。",
    },
    {
        "category": "数据库",
        "knowledge_points": ["分区表", "大表治理"],
        "term": "分区表",
        "correct": "改善大表管理和部分范围查询性能",
        "wrongs": ["替代数据库备份", "消除所有 JOIN", "只用于日志压缩"],
        "analysis": "分区表适合大规模数据管理，但要结合访问模式设计分区策略。",
    },
    {
        "category": "软件工程",
        "knowledge_points": ["代码评审", "质量控制"],
        "term": "代码评审",
        "correct": "在上线前尽早发现缺陷和设计问题",
        "wrongs": ["替代自动化测试", "取消需求分析", "只统计代码行数"],
        "analysis": "代码评审不仅是查错，也能统一编码规范和设计思路。",
    },
    {
        "category": "软件工程",
        "knowledge_points": ["持续集成", "研发流程"],
        "term": "持续集成",
        "correct": "让代码频繁集成并尽早暴露集成问题",
        "wrongs": ["让开发长期不合并分支", "只在上线后执行构建", "取消自动化校验"],
        "analysis": "持续集成强调快速反馈和小步提交，是现代研发流程基础。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["限流", "高可用"],
        "term": "限流",
        "correct": "在高峰期保护系统关键资源并控制请求速率",
        "wrongs": ["提升磁盘容量", "替代数据库事务", "只用于图片处理"],
        "analysis": "限流是高可用治理基础策略，常与熔断、降级配合使用。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["熔断", "容错设计"],
        "term": "熔断器",
        "correct": "在下游故障时快速失败，避免级联扩散",
        "wrongs": ["替代日志采集", "只用于前端打包", "保证请求全部成功"],
        "analysis": "熔断是服务治理关键手段，目的不是成功率绝对提升，而是保护系统稳定。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["降级", "可用性"],
        "term": "服务降级",
        "correct": "在资源紧张或故障时优先保障核心能力可用",
        "wrongs": ["强制关闭全部服务", "取消监控告警", "只提高 UI 细节"],
        "analysis": "降级强调保核心、舍次要，是高可用体系的重要组成部分。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["灰度发布", "发布治理"],
        "term": "灰度发布",
        "correct": "分批验证新版本，降低全量发布风险",
        "wrongs": ["要求所有用户同时切换", "取消回滚能力", "只适用于数据库脚本"],
        "analysis": "灰度发布是成熟发布治理体系的重要环节，常与监控和回滚联动。",
    },
    {
        "category": "系统安全",
        "knowledge_points": ["多因素认证", "身份安全"],
        "term": "多因素认证",
        "correct": "通过多种不同类型凭证提升身份验证安全性",
        "wrongs": ["只依赖静态密码", "取消审计日志", "替代防火墙"],
        "analysis": "多因素认证可显著降低单一凭据泄露带来的风险。",
    },
    {
        "category": "系统安全",
        "knowledge_points": ["访问控制", "RBAC"],
        "term": "基于角色的访问控制",
        "correct": "通过角色聚合权限，提升授权管理效率",
        "wrongs": ["所有用户默认管理员权限", "替代审计追踪", "等同于数据加密"],
        "analysis": "RBAC 适合中大型系统的权限治理，是安全题稳定考点。",
    },
    {
        "category": "系统安全",
        "knowledge_points": ["零信任", "最小权限"],
        "term": "零信任架构",
        "correct": "持续验证访问主体并实施细粒度最小权限控制",
        "wrongs": ["内网默认完全可信", "取消身份体系", "只依赖单点防火墙"],
        "analysis": "零信任强调“永不默认信任”，是近年高频新方向。",
    },
    {
        "category": "新兴技术",
        "knowledge_points": ["数字孪生", "工业互联网"],
        "term": "数字孪生",
        "correct": "构建物理实体的数字映射以支持监测、分析和优化",
        "wrongs": ["替代 VPN 连接", "只做静态网页", "取消传感器采集"],
        "analysis": "数字孪生强调实体、数据与模型映射，是工业和运维新趋势。",
    },
    {
        "category": "新兴技术",
        "knowledge_points": ["MLOps", "模型工程化"],
        "term": "MLOps",
        "correct": "把模型训练、部署、监控和治理流程工程化",
        "wrongs": ["只负责购买 GPU", "取消数据版本管理", "替代业务测试"],
        "analysis": "MLOps 是 AI 工程化核心，和 CI/CD 的思想相通但对象不同。",
    },
    {
        "category": "新兴技术",
        "knowledge_points": ["隐私计算", "安全计算"],
        "term": "隐私计算",
        "correct": "在保护敏感数据不直接暴露的前提下进行协同计算",
        "wrongs": ["公开全部训练样本", "只做前端渲染", "替代容灾方案"],
        "analysis": "隐私计算是新技术热点，重点在“数据可用不可见”的能力。",
    },
    {
        "category": "云原生",
        "knowledge_points": ["自动扩缩容", "弹性"],
        "term": "自动扩缩容",
        "correct": "根据负载变化动态调整资源规模",
        "wrongs": ["要求固定所有实例数量", "取消监控采集", "替代镜像仓库"],
        "analysis": "弹性伸缩是云原生平台的重要能力，目标是兼顾性能和成本。",
    },
    {
        "category": "云原生",
        "knowledge_points": ["镜像仓库", "制品管理"],
        "term": "镜像仓库",
        "correct": "集中存储和分发容器镜像等交付制品",
        "wrongs": ["替代配置中心", "直接做流量调度", "只保存数据库日志"],
        "analysis": "镜像仓库是容器交付链路的关键组件，常和 CI/CD 配合使用。",
    },
    {
        "category": "分布式",
        "knowledge_points": ["分布式缓存", "热点数据"],
        "term": "本地缓存 + 分布式缓存",
        "correct": "通过多级缓存降低远程访问压力并提升响应速度",
        "wrongs": ["取消数据一致性考虑", "让数据库不可用", "只适用于单线程程序"],
        "analysis": "多级缓存能提升性能，但缓存一致性和失效策略必须设计。",
    },
    {
        "category": "分布式",
        "knowledge_points": ["消息队列", "削峰填谷"],
        "term": "消息队列",
        "correct": "缓冲流量并实现异步解耦",
        "wrongs": ["替代全部数据库", "保证没有重复消费", "取消幂等设计"],
        "analysis": "消息队列能提升系统弹性，但顺序、重复和一致性仍需治理。",
    },
    {
        "category": "专业英语",
        "knowledge_points": ["redundancy", "专业英语"],
        "term": "redundancy",
        "correct": "通常表示冗余",
        "wrongs": ["事务", "时延", "监控"],
        "analysis": "redundancy 在高可用和容灾设计语境中经常出现。",
    },
    {
        "category": "专业英语",
        "knowledge_points": ["reliability", "专业英语"],
        "term": "reliability",
        "correct": "通常表示可靠性",
        "wrongs": ["扩展性", "部署", "回归测试"],
        "analysis": "reliability 是系统质量属性和论文题的高频词。",
    },
    {
        "category": "项目管理",
        "knowledge_points": ["范围管理", "WBS"],
        "term": "WBS",
        "correct": "把项目工作逐层分解为可管理的工作包",
        "wrongs": ["只用于数据库分表", "等同于甘特图", "只统计接口耗时"],
        "analysis": "WBS 是项目范围和计划管理基础工具，经常和关键路径一起考。",
    },
    {
        "category": "项目管理",
        "knowledge_points": ["沟通管理", "干系人"],
        "term": "干系人分析",
        "correct": "识别不同参与方诉求并优化沟通策略",
        "wrongs": ["替代性能压测", "等同于代码走查", "只用于验收阶段"],
        "analysis": "项目管理题很多分数丢在概念不清，干系人管理是常见送分点。",
    },
    {
        "category": "企业架构",
        "knowledge_points": ["业务架构", "技术架构"],
        "term": "企业架构治理",
        "correct": "保证业务目标与数据、应用和技术能力协同演进",
        "wrongs": ["只负责购买服务器", "取消架构评审", "仅约束前端配色"],
        "analysis": "企业架构不只是画图，更是规划、治理和对齐业务目标的体系。",
    },
]


SCENARIO_BANK = [
    {
        "category": "计算机系统基础",
        "knowledge_points": ["总线", "I/O"],
        "scenario": "减少高速设备与 CPU 之间的数据搬运开销",
        "correct": "采用 DMA 方式进行数据传输",
        "wrongs": ["只用轮询等待", "关闭中断机制", "取消缓存层"],
        "analysis": "在大量 I/O 搬运场景中，DMA 是经典正确解法。",
    },
    {
        "category": "操作系统",
        "knowledge_points": ["死锁避免", "银行家算法"],
        "scenario": "动态判断资源分配后系统是否仍处于安全状态",
        "correct": "采用银行家算法进行死锁避免",
        "wrongs": ["统一重启全部进程", "关闭调度器", "只增加内存页大小"],
        "analysis": "银行家算法是死锁避免的代表性方法，常考定义和适用场景。",
    },
    {
        "category": "网络",
        "knowledge_points": ["CDN", "静态资源"],
        "scenario": "降低热点静态资源访问对源站的压力",
        "correct": "引入 CDN 做边缘缓存分发",
        "wrongs": ["把所有资源放入数据库事务", "关闭浏览器缓存", "只增加本地日志量"],
        "analysis": "CDN 是大流量静态内容分发的常见标准答案。",
    },
    {
        "category": "网络",
        "knowledge_points": ["四层负载均衡", "七层负载均衡"],
        "scenario": "按 URL 或 Header 做精细化流量路由",
        "correct": "采用七层负载均衡方案",
        "wrongs": ["只使用 MAC 地址转发", "关闭应用层协议解析", "只做磁盘镜像"],
        "analysis": "七层负载均衡能识别应用层信息，是精细流量治理基础。",
    },
    {
        "category": "数据库",
        "knowledge_points": ["热点数据", "缓存"],
        "scenario": "降低高频只读数据对数据库的直接查询压力",
        "correct": "优先通过缓存承接热点读流量",
        "wrongs": ["关闭所有索引", "取消读写分离", "把全部查询改成事务串行执行"],
        "analysis": "热点只读场景优先考虑缓存，是数据库和架构设计交叉高频题。",
    },
    {
        "category": "数据库",
        "knowledge_points": ["分库分表", "容量扩展"],
        "scenario": "单表数据规模和写入压力都持续增长",
        "correct": "按业务规则进行分库分表设计",
        "wrongs": ["删除主键约束", "关闭备份", "让所有请求只走单实例"],
        "analysis": "分库分表的本质是容量和吞吐扩展，但会增加路由和一致性复杂度。",
    },
    {
        "category": "软件工程",
        "knowledge_points": ["需求确认", "原型"],
        "scenario": "快速让用户看到系统雏形并确认需求方向",
        "correct": "采用原型法或高保真交互原型辅助沟通",
        "wrongs": ["直接进入编码并拒绝反馈", "只做数据库脚本", "完全不编写需求文档"],
        "analysis": "当需求模糊时，原型是高效的确认工具，芝士架构课程也强调这一点。",
    },
    {
        "category": "软件工程",
        "knowledge_points": ["质量保证", "测试左移"],
        "scenario": "尽早发现缺陷并降低修复成本",
        "correct": "把测试活动前移到需求和开发阶段",
        "wrongs": ["只在上线后再测试", "完全取消自动化测试", "所有问题都交给运维处理"],
        "analysis": "测试左移是质量工程的重要思想，也是论文和上午题都常见的点。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["无状态", "微服务"],
        "scenario": "支持服务实例水平扩展并方便故障替换",
        "correct": "优先采用无状态服务并把状态外置",
        "wrongs": ["把会话都保存在本地内存且强依赖单实例", "固定只能单机部署", "关闭负载均衡"],
        "analysis": "无状态化是微服务和弹性扩容的关键设计原则之一。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["配置中心", "微服务治理"],
        "scenario": "统一管理多服务环境配置并支持动态刷新",
        "correct": "建设集中式配置中心",
        "wrongs": ["把配置硬编码在每个服务里", "删除环境隔离", "取消版本控制"],
        "analysis": "配置中心是微服务治理基础能力之一，有利于统一管理与审计。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["注册中心", "服务治理"],
        "scenario": "让服务实例动态上线下线后仍能被调用方及时发现",
        "correct": "使用注册中心和服务发现机制",
        "wrongs": ["在代码里写死全部地址", "关闭健康检查", "只依赖本地 hosts"],
        "analysis": "服务注册发现是弹性架构基础设施，不然扩缩容和故障摘除都很困难。",
    },
    {
        "category": "软件架构设计",
        "knowledge_points": ["链路追踪", "可观测性"],
        "scenario": "快速定位跨多个微服务的请求耗时瓶颈",
        "correct": "建设链路追踪体系",
        "wrongs": ["只看 CPU 温度", "只记录部署时间", "完全关闭日志"],
        "analysis": "Trace 是微服务排障利器，尤其适合跨服务性能问题定位。",
    },
    {
        "category": "系统安全",
        "knowledge_points": ["敏感数据", "加密"],
        "scenario": "防止数据库介质泄露后直接暴露敏感信息",
        "correct": "对敏感数据进行存储加密或字段加密",
        "wrongs": ["只增加字段长度", "关闭权限控制", "取消日志脱敏"],
        "analysis": "加密是保护敏感数据的重要手段，但要配合密钥管理和访问控制。",
    },
    {
        "category": "系统安全",
        "knowledge_points": ["最小权限", "安全治理"],
        "scenario": "降低账号被滥用或误操作造成的影响范围",
        "correct": "严格实施最小权限控制",
        "wrongs": ["给所有账号管理员权限", "不做权限审计", "删除身份认证"],
        "analysis": "最小权限是安全基础原则，在案例和论文题中都很常见。",
    },
    {
        "category": "新兴技术",
        "knowledge_points": ["RAG", "知识库"],
        "scenario": "让大模型回答更贴近企业私有知识并降低幻觉",
        "correct": "通过检索增强生成引入外部知识上下文",
        "wrongs": ["完全关闭检索模块", "只依赖随机提示词", "取消知识更新"],
        "analysis": "RAG 是当前 AI 应用工程化高频考点，尤其适合企业知识问答。",
    },
    {
        "category": "新兴技术",
        "knowledge_points": ["向量检索", "语义搜索"],
        "scenario": "基于语义相似度召回与查询含义接近的内容",
        "correct": "引入向量检索能力",
        "wrongs": ["只依赖精确字符串匹配", "关闭嵌入模型", "取消索引结构"],
        "analysis": "语义搜索的关键基础设施就是向量化与近邻检索。",
    },
    {
        "category": "云原生",
        "knowledge_points": ["弹性伸缩", "自动扩容"],
        "scenario": "在业务高峰来临时自动补足服务实例数量",
        "correct": "根据监控指标触发自动扩缩容",
        "wrongs": ["只依赖人工深夜手动扩容", "固定资源不允许变化", "关闭负载均衡"],
        "analysis": "弹性伸缩是云平台价值体现，关键在指标、策略和冷启动控制。",
    },
    {
        "category": "云原生",
        "knowledge_points": ["滚动发布", "回滚"],
        "scenario": "不中断服务地逐步替换旧版本实例",
        "correct": "采用滚动发布策略",
        "wrongs": ["一次性强杀全部旧实例", "只允许停机升级", "取消健康检查探针"],
        "analysis": "滚动发布是云原生部署常规能力，和探针、回滚联动使用。",
    },
    {
        "category": "分布式",
        "knowledge_points": ["幂等", "消息消费"],
        "scenario": "消息重复投递时仍避免业务重复执行",
        "correct": "在消费侧设计幂等控制",
        "wrongs": ["关闭消息确认机制", "禁止异常重试", "删除业务主键"],
        "analysis": "幂等是至少一次投递模型下的重要治理手段，是高频送分点。",
    },
    {
        "category": "分布式",
        "knowledge_points": ["布隆过滤器", "缓存穿透"],
        "scenario": "快速拦截明显不存在的数据请求以保护后端数据库",
        "correct": "在缓存前增加布隆过滤器",
        "wrongs": ["让所有请求直接访问数据库", "关闭缓存层", "取消权限校验"],
        "analysis": "布隆过滤器是治理缓存穿透的经典方法之一。",
    },
    {
        "category": "分布式",
        "knowledge_points": ["一致性哈希", "缓存集群"],
        "scenario": "在缓存节点增减时尽量减少大量数据重新映射",
        "correct": "采用一致性哈希分布策略",
        "wrongs": ["只按随机数分配", "固定所有节点不可扩容", "取消分布式路由"],
        "analysis": "一致性哈希是分布式缓存、分布式路由经典知识点。",
    },
    {
        "category": "项目管理",
        "knowledge_points": ["压缩进度", "资源管理"],
        "scenario": "在关键路径活动上缩短项目总工期",
        "correct": "优先分析关键路径并针对关键活动做压缩",
        "wrongs": ["只修改非关键路径任务", "取消风险管理", "关闭项目监控"],
        "analysis": "进度压缩一定要看关键路径，否则不一定有效。",
    },
    {
        "category": "项目管理",
        "knowledge_points": ["风险应对", "应急预案"],
        "scenario": "在高风险任务可能失败时提前准备替代措施",
        "correct": "制定风险应对计划和应急预案",
        "wrongs": ["忽略风险直到问题发生", "只在验收后处理", "完全依赖个人经验"],
        "analysis": "风险管理看的是提前识别和准备，不是事后补救。",
    },
    {
        "category": "专业英语",
        "knowledge_points": ["availability", "专业英语"],
        "scenario": "描述系统可正常提供服务的能力",
        "correct": "使用 availability 这一术语",
        "wrongs": ["使用 latency 表示", "使用 throughput 表示", "使用 redundancy 表示"],
        "analysis": "专业英语题要把术语和常见系统质量语义建立稳定映射。",
    },
]


def build_questions():
    questions = []
    next_id = 600001

    def append_questions(bank, stems, stage):
        nonlocal next_id
        for entry in bank:
            for variant_index, stem_template in enumerate(stems):
                year = YEARS[(next_id + variant_index) % len(YEARS)]
                stem = stem_template.format(
                    term=entry.get("term", ""),
                    scenario=entry.get("scenario", ""),
                )

                options = [entry["correct"], *entry["wrongs"]]
                correct_position = (next_id + variant_index) % 4
                rotated = options[1:] + options[:1]
                arranged = rotated[:]
                arranged.insert(correct_position, entry["correct"])
                unique_options = []
                for option in arranged:
                    if option not in unique_options:
                        unique_options.append(option)
                if entry["correct"] not in unique_options:
                    unique_options.insert(correct_position, entry["correct"])
                while len(unique_options) < 4:
                    unique_options.append("以上说法均不准确")

                labels = OPTION_LABELS
                option_items = [
                    {"id": label, "label": label, "content": content}
                    for label, content in zip(labels, unique_options[:4])
                ]
                correct_label = labels[unique_options[:4].index(entry["correct"])]

                questions.append(
                    {
                        "id": next_id,
                        "year": year,
                        "stage": stage,
                        "type": "singleChoice",
                        "category": entry["category"],
                        "knowledgePoints": entry["knowledge_points"],
                        "stem": stem,
                        "options": option_items,
                        "correctAnswers": [correct_label],
                        "analysis": entry["analysis"],
                        "score": 1,
                        "estimatedMinutes": 2,
                    }
                )
                next_id += 1

    append_questions(DEFINITION_BANK, DEFINITION_STEMS, "上午专题改编")
    append_questions(PURPOSE_BANK, PURPOSE_STEMS, "上午专题改编")
    append_questions(SCENARIO_BANK, SCENARIO_STEMS, "上午专题改编")
    return questions


def main():
    output_path = Path(
        "/Users/yaolijun/Documents/iphoneApp/ruanKao/RuanKao/Resources/Seeds/questions_massive_pack.json"
    )
    questions = build_questions()
    output_path.write_text(
        json.dumps(questions, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"generated {len(questions)} questions -> {output_path}")


if __name__ == "__main__":
    main()
