#!/usr/bin/env python3

import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT_PATH = ROOT / "Tools/expand_cheko_style_pack.py"
OUTPUT_PATH = ROOT / "RuanKao/Resources/Seeds/questions_cheko_extension_pack.json"
START_ID = 9001


def load_base_module():
    spec = importlib.util.spec_from_file_location("cheko_base", BASE_SCRIPT_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("无法加载芝士架构基础题包脚本。")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


BASE = load_base_module()
YEARS = BASE.YEARS
OPTION_LABELS = BASE.OPTION_LABELS
OBJECTIVE_TEMPLATES = BASE.OBJECTIVE_TEMPLATES


OBJECTIVE_EXTENSION = [
    BASE.objective("purpose", "系统规划与分析", ["可行性分析", "立项评估"], "可行性分析", "在立项前综合评估项目在技术、经济、进度、法律和用户等方面是否值得实施", ["项目上线后的绩效考核方式", "接口字段命名风格", "测试报告的排版格式"], "芝士架构风格很强调“先判断值不值得做，再讨论怎么做”，可行性分析就是立项入口。"),
    BASE.objective("purpose", "业务流程分析", ["价值链分析", "流程优化"], "价值链分析法", "识别关键业务活动及其价值贡献，从而发现流程优化和竞争优势切入点", ["只统计数据库表数量", "直接替代项目排期计划", "专门用于部署容器集群"], "价值链分析看的是业务活动如何创造价值，不是单纯画流程图。"),
    BASE.objective("definition", "处理流程设计", ["IPO 图", "模块设计"], "IPO 图", "围绕输入、处理和输出描述模块内部加工逻辑的表达方式", ["只用于描述数据库表结构", "专门记录接口 SLA 指标", "等同于网络拓扑图"], "IPO 是上午题里很稳的基础工具，核心是把模块看成“输入—加工—输出”的过程。"),
    BASE.objective("scenario", "处理流程设计", ["判定表", "规则表达"], "需要表达多个条件组合及对应处理动作，且希望规则关系清晰可核对", "采用判定表对条件和动作进行组合化表达", ["只画一张部署图", "改用 ER 图描述字段关系", "把全部规则写进自然语言段落"], "判定表适合“条件多、组合多、动作明确”的场景，是规则类题目的高频答案。"),
    BASE.objective("purpose", "工作流", ["工作流参考模型", "WFMS"], "工作流参考模型", "统一描述工作流管理系统各核心接口和组件之间的协同关系", ["专门替代数据库事务机制", "用于计算服务器 CPU 利用率", "等同于消息队列主题命名规范"], "芝士架构公开内容会反复强调 WRM/WFMS 这类基础模型，记住“模块和接口”比死背缩写更重要。"),
    BASE.objective("definition", "面向对象设计", ["实体类", "ECB"], "实体类", "承载业务领域核心信息与长期状态的对象", ["只负责界面输入输出", "专门负责协调用例流程", "表示网络交换机节点"], "实体类考的是对象职责边界：它保存业务状态，而不是承接界面或调度逻辑。"),
    BASE.objective("scenario", "面向对象设计", ["控制类", "ECB"], "在一个用例执行过程中，需要协调边界类和实体类完成业务流程", "将该调度与协同行为建模为控制类", ["把所有逻辑都塞进实体类", "把流程控制交给边界类长期保存", "直接改成数据库触发器"], "控制类的关键词是“协调流程”，芝士架构风格会特别强调职责不要混。"),
    BASE.objective("purpose", "结构化设计", ["高内聚低耦合", "模块独立性"], "提高模块独立性", "降低修改影响范围并提升理解、测试和维护效率", ["让所有模块共享全局变量", "把全部功能合并成单个模块", "取消接口分层"], "高内聚低耦合不是口号，它直接关系到演进成本和缺陷扩散范围。"),
    BASE.objective("definition", "结构化设计", ["扇入扇出", "模块设计"], "模块扇出", "一个模块直接调用的下层模块数量", ["调用该模块的上层模块数量", "模块拥有的数据表数量", "模块每秒处理的请求数"], "扇入/扇出是经典结构化设计考点，容易在概念题里对调。"),
    BASE.objective("purpose", "软件测试", ["白盒测试", "覆盖率"], "判定覆盖", "保证程序中每个判定的真假结果至少都执行一次", ["保证所有路径都被完整执行", "只要求每条语句执行一次即可", "保证每个需求都映射到一条用例"], "覆盖率题最怕层次混淆，芝士架构风格会让你先分清“语句—判定—条件—路径”。"),
    BASE.objective("definition", "数据库", ["范式", "数据依赖"], "第三范式", "在满足第二范式基础上，消除非主属性对码的传递依赖", ["要求每个字段都必须可为空", "强制所有表都只保留两个字段", "只处理主属性对码的部分依赖"], "范式题要回到“异常为什么发生”来理解，第三范式解决的是传递依赖导致的更新异常。"),
    BASE.objective("purpose", "操作系统", ["页面置换", "局部性原理"], "LRU 页面置换算法", "优先淘汰最近最长时间未被访问的页面，以利用程序访问局部性", ["总是淘汰最早进入内存的页面", "随机淘汰当前页表中的任意页面", "每次都淘汰占用空间最大的页面"], "LRU 高频但不难，抓住“最近最久未使用”这句话就不容易错。"),
    BASE.objective("definition", "操作系统", ["死锁", "并发控制"], "死锁的必要条件", "互斥、请求与保持、不剥夺和循环等待同时成立", ["只要发生上下文切换就一定死锁", "只要系统有等待队列就一定死锁", "只要使用信号量就一定死锁"], "死锁四条件是上午题常客，最稳的记法就是“缺一个都不构成死锁”。"),
    BASE.objective("definition", "网络", ["TCP", "可靠传输"], "TCP 三次握手", "在通信双方之间建立可靠连接并确认收发能力与初始序号", ["用于定期清理失效缓存数据", "专门负责静态网页压缩", "只在数据库主从复制时使用"], "三次握手考的是“为什么不是两次”，核心是双方都要确认对方的收发能力。"),
    BASE.objective("definition", "专业英语", ["术语辨析", "英文阅读"], "throughput", "单位时间内系统能够处理的工作量或数据量", ["系统从故障中恢复所需时间", "单个请求从发送到返回的等待时间", "系统支持的最大用户角色数"], "专业英语题属于芝士架构里强调的稳分项，throughput 常和 latency、availability 混考。"),
    BASE.objective("definition", "专业英语", ["术语辨析", "英文阅读"], "availability", "系统在规定条件和时间范围内持续可用的能力", ["系统横向扩容的最大副本数", "数据库表字段的完整性约束", "软件版本上线的发布时间窗"], "availability 直译为可用性，和性能、吞吐量不是同一个维度。"),
    BASE.objective("scenario", "项目管理", ["挣值分析", "进度成本"], "项目经理想判断当前项目进度是超前还是滞后，并希望有可量化指标支撑", "计算 SPI = EV / PV，并据此判断进度状态", ["只看 AC 是否增长", "只比较团队人数是否增加", "只根据风险清单条目数量判断"], "挣值管理题不复杂，核心是把 PV、EV、AC 和 SPI、CPI 对应起来。"),
]


CASE_STUDIES_EXTENSION = [
    {
        "category": "工作流",
        "knowledgePoints": ["工作流引擎", "表单编排", "流程监控"],
        "stem": "某集团审批系统流程种类多、变更频繁，研发每次都要改代码发版，导致业务响应慢。请分析工作流管理平台的架构设计方案。",
        "focus": "流程建模、规则外置、表单集成、流程引擎、权限控制、监控审计和版本管理",
        "hint": "流程外置与规则编排",
    },
    {
        "category": "面向对象设计",
        "knowledgePoints": ["ECB", "职责划分", "系统建模"],
        "stem": "某订单管理系统在需求扩展后，界面逻辑、业务逻辑和数据对象严重耦合，修改一个页面常常牵连多个模块。请从面向对象设计角度分析重构方案。",
        "focus": "边界类、控制类、实体类划分，用例驱动建模，职责边界、复用方式和扩展机制",
        "hint": "职责边界与类建模",
    },
    {
        "category": "WEB 应用",
        "knowledgePoints": ["高并发", "缓存", "安全控制"],
        "stem": "某门户系统在大促期间出现页面加载缓慢、登录重试增多和接口偶发超时等问题。请分析 Web 应用架构优化思路。",
        "focus": "静动态分离、缓存分层、会话治理、限流降级、鉴权控制、监控告警和容量评估",
        "hint": "性能与安全双线优化",
    },
    {
        "category": "数据库",
        "knowledgePoints": ["读写分离", "索引优化", "事务边界"],
        "stem": "某会员中心数据库随着业务增长出现慢查询增多、锁等待严重和备库延迟高等问题。请分析数据库架构改进方案。",
        "focus": "索引设计、SQL 优化、事务粒度、读写分离、缓存协同、容量扩展和监控治理",
        "hint": "事务与索引协同优化",
    },
    {
        "category": "系统规划与分析",
        "knowledgePoints": ["可行性分析", "业务流程优化", "立项决策"],
        "stem": "某企业计划建设统一业务中台，但内部部门流程差异较大、历史系统复杂且预算受限。请分析项目在规划与立项阶段应重点关注的内容。",
        "focus": "业务现状调研、流程梳理、可行性分析、收益评估、范围界定、实施路径和风险识别",
        "hint": "先立项评估再方案落地",
    },
]


ESSAYS_EXTENSION = [
    {
        "category": "工作流",
        "knowledgePoints": ["流程引擎", "规则配置", "审计追踪"],
        "stem": "请结合实际项目，论述工作流管理系统的架构设计与应用实践，重点说明流程建模、规则外置和审计监管。",
        "focus": "流程建模、规则外置、流程引擎、权限审计和版本治理",
    },
    {
        "category": "面向对象设计",
        "knowledgePoints": ["职责划分", "设计原则", "系统演进"],
        "stem": "请结合实际项目，论述面向对象设计在复杂业务系统中的应用实践，重点说明职责划分、设计原则和演进治理。",
        "focus": "ECB 划分、职责边界、复用策略、扩展能力和重构演进",
    },
    {
        "category": "软件架构设计",
        "knowledgePoints": ["架构评估", "质量属性", "权衡分析"],
        "stem": "请结合实际项目，论述软件架构评估与优化实践，重点说明质量属性、权衡分析和改进闭环。",
        "focus": "质量属性、场景分析、权衡取舍、评估方法和优化闭环",
    },
    {
        "category": "WEB 应用",
        "knowledgePoints": ["高可用", "缓存", "安全控制"],
        "stem": "请结合实际项目，论述高可用 Web 应用架构设计与应用实践，重点说明性能优化、稳定性保障和安全控制。",
        "focus": "静动态分离、缓存体系、流量治理、安全控制和应急预案",
    },
]


def build_objective_questions(start_id: int):
    questions = []
    next_id = start_id

    for entry_index, entry in enumerate(OBJECTIVE_EXTENSION):
        templates = OBJECTIVE_TEMPLATES[entry["mode"]]
        for variant_index, template in enumerate(templates):
            year = YEARS[(entry_index + variant_index) % len(YEARS)]
            stem = template.format(value=entry["term_or_scenario"])
            correct_index = (entry_index * 5 + variant_index) % 4
            options = entry["wrongs"][:]
            options.insert(correct_index, entry["correct"])
            option_items = [
                {"id": label, "label": label, "content": content}
                for label, content in zip(OPTION_LABELS, options)
            ]
            questions.append(
                {
                    "id": next_id,
                    "year": year,
                    "stage": "上午专题补充",
                    "type": "singleChoice",
                    "category": entry["category"],
                    "knowledgePoints": entry["knowledgePoints"],
                    "stem": stem,
                    "options": option_items,
                    "correctAnswers": [OPTION_LABELS[correct_index]],
                    "analysis": entry["analysis"],
                    "score": 1,
                    "estimatedMinutes": 2,
                }
            )
            next_id += 1

    return questions, next_id


def build_case_questions(start_id: int):
    questions = []
    next_id = start_id

    for index, entry in enumerate(CASE_STUDIES_EXTENSION):
        questions.append(
            {
                "id": next_id,
                "year": YEARS[index % len(YEARS)],
                "stage": "下午案例补充",
                "type": "caseStudy",
                "category": entry["category"],
                "knowledgePoints": entry["knowledgePoints"],
                "stem": entry["stem"],
                "options": [],
                "correctAnswers": [f"可从{entry['focus']}等方面展开。"],
                "analysis": f"这类案例题建议按“背景—问题—方案—落地—收益”分段作答，重点写清{entry['hint']}。",
                "score": 25,
                "estimatedMinutes": 20,
            }
        )
        next_id += 1

    return questions, next_id


def build_essay_questions(start_id: int):
    questions = []
    next_id = start_id

    for index, entry in enumerate(ESSAYS_EXTENSION):
        questions.append(
            {
                "id": next_id,
                "year": YEARS[index % len(YEARS)],
                "stage": "论文题补充",
                "type": "essay",
                "category": entry["category"],
                "knowledgePoints": entry["knowledgePoints"],
                "stem": entry["stem"],
                "options": [],
                "correctAnswers": ["建议从项目背景、目标、总体方案、关键机制、实施效果和经验反思等方面展开。"],
                "analysis": f"论文题不要空谈概念，建议把{entry['focus']}写进真实项目脉络，并体现取舍与复盘。",
                "score": 75,
                "estimatedMinutes": 45,
            }
        )
        next_id += 1

    return questions


def main():
    objective_questions, next_id = build_objective_questions(START_ID)
    case_questions, next_id = build_case_questions(next_id)
    essay_questions = build_essay_questions(next_id)

    questions = objective_questions + case_questions + essay_questions
    OUTPUT_PATH.write_text(json.dumps(questions, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "generated cheko extension pack:",
        f"objective={len(objective_questions)}",
        f"case={len(case_questions)}",
        f"essay={len(essay_questions)}",
        f"total={len(questions)}",
        f"path={OUTPUT_PATH}",
    )


if __name__ == "__main__":
    main()
