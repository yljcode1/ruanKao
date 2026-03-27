#!/usr/bin/env python3

import importlib.util
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_SCRIPT_PATH = ROOT / "Tools/expand_cheko_style_pack.py"
EXTENSION_SCRIPT_PATH = ROOT / "Tools/generate_cheko_extension_pack.py"
OUTPUT_PATH = ROOT / "RuanKao/Resources/Seeds/questions_cheko_boost_pack.json"
START_ID = 700001


def load_module(module_name: str, path: Path):
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"无法加载模块：{path}")

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


BASE = load_module("cheko_base_source", BASE_SCRIPT_PATH)
EXTENSION = load_module("cheko_extension_source", EXTENSION_SCRIPT_PATH)
YEARS = BASE.YEARS
OPTION_LABELS = BASE.OPTION_LABELS


OBJECTIVE_TEMPLATES = {
    "definition": [
        "如果题目考查{value}的准确定义，下列理解正确的是：",
        "围绕{value}这一术语，最符合工程语境的说法是：",
        "在软考高频概念里，{value}通常表示：",
        "下列选项中，对{value}解释最准确的是：",
        "将{value}放到真实项目里，正确理解应是：",
        "题干出现{value}时，优先联想到的是：",
        "从方法论角度看，{value}指的是：",
        "关于{value}这一基本概念，哪项表述正确：",
        "在系统分析与架构设计中，{value}更准确地是：",
        "如果要一句话说明{value}，正确说法是：",
        "围绕{value}的定义，下列哪项最贴切：",
        "在工程实践中，{value}一般被理解为：",
        "当复盘知识点{value}时，正确结论是：",
        "对于{value}，以下理解中正确的是：",
        "围绕{value}的本质含义，下列说法正确的是：",
        "在考试语境下提到{value}，通常是指：",
    ],
    "purpose": [
        "引入{value}，最先要解决的问题通常是：",
        "项目采用{value}，核心目标一般在于：",
        "从收益角度看，{value}最直接的价值是：",
        "在方案设计中使用{value}，主要是为了：",
        "如果团队决定建设{value}，首要诉求通常是：",
        "围绕{value}的建设目标，下列说法正确的是：",
        "在复杂系统里落地{value}，通常想优先改善：",
        "从治理视角看，{value}带来的关键收益是：",
        "采用{value}方案，通常最想达成的是：",
        "在实际项目中，{value}常用来解决：",
        "如果题目问{value}“为什么要做”，正确答案通常是：",
        "就工程价值而言，{value}重点在于：",
        "把{value}纳入架构方案，主要考虑的是：",
        "对{value}的目的理解正确的是：",
        "围绕{value}的落地收益，最核心的一项是：",
        "在软考题里，{value}通常用于实现：",
    ],
    "scenario": [
        "项目若要做到“{value}”，优先采用的方案是：",
        "面对“{value}”这一诉求，更合理的处理方式是：",
        "如果场景要求“{value}”，通常应选择：",
        "当系统需要“{value}”时，首选做法一般是：",
        "针对“{value}”这类问题，较优方案通常是：",
        "题干描述为“{value}”时，应优先考虑：",
        "为满足“{value}”，架构上更合适的动作是：",
        "出现“{value}”这类场景时，首先应采用：",
        "如果项目遇到“{value}”，一般推荐：",
        "处理“{value}”这类工程问题，更可取的是：",
        "若要支撑“{value}”，通常需要：",
        "围绕“{value}”进行设计时，最合适的选择是：",
        "面对“{value}”的业务目标，优先策略通常是：",
        "当需求变成“{value}”时，合理方案是：",
        "题目要求实现“{value}”，推荐先做：",
        "针对“{value}”这个高频场景，更稳妥的做法是：",
    ],
}


ADDITIONAL_OBJECTIVES = [
    BASE.objective("purpose", "系统规划与分析", ["风险分析", "立项决策"], "风险分析", "识别项目实施过程中的关键不确定因素并提前制定应对策略", ["只统计开发人员数量变化", "专门用于美化汇报材料", "上线后再决定是否补救"], "系统规划题很讲究“先识别风险，再谈控制动作”，风险分析就是前置判断。"),
    BASE.objective("definition", "需求工程", ["需求跟踪", "变更控制"], "需求跟踪矩阵", "建立需求与设计、开发、测试和交付物之间的对应关系", ["专门记录数据库索引命名方式", "替代系统监控大盘", "仅用于统计代码行数"], "需求跟踪矩阵高频但不难，抓住“前后关联、可追溯”这两个关键词就稳了。"),
    BASE.objective("purpose", "需求工程", ["原型法", "需求确认"], "原型法", "在需求不够清晰时通过快速样例帮助用户确认真实诉求", ["把所有需求延后到验收阶段再定", "取消需求评审会议", "直接跳过用户反馈"], "原型法的价值不是画得多漂亮，而是尽快对齐认知并暴露歧义。"),
    BASE.objective("scenario", "UML 建模", ["用例图", "系统边界"], "需要表达系统参与者与主要业务功能之间的关系边界", "优先使用用例图刻画参与者、系统边界和核心功能", ["只画数据库 E-R 图", "改用网络拓扑图表达", "把全部流程写成自然语言段落"], "建模题先看“想表达什么关系”，如果是参与者和功能边界，先想到用例图。"),
    BASE.objective("definition", "软件工程", ["配置管理", "基线"], "基线", "经过正式评审并可作为后续开发与变更依据的稳定配置项版本", ["尚未讨论的临时想法集合", "测试环境中的随机快照", "专门表示缺陷优先级等级"], "基线强调“经确认、可追踪、可作为参照”，它不是随手存一个版本。"),
    BASE.objective("purpose", "软件工程", ["CMMI", "过程改进"], "CMMI", "通过过程能力成熟度提升组织的软件研发与管理水平", ["替代所有项目技术方案设计", "只用于控制数据库访问权限", "专门衡量服务器硬件性能"], "CMMI 关注的是组织过程能力，不是某一个开发工具或单次项目表现。"),
    BASE.objective("definition", "数据库", ["视图", "数据安全"], "视图", "基于查询结果定义的虚拟表，用于简化访问和增强数据隔离", ["表示磁盘上的真实物理文件", "只能用于删除主键约束", "专门替代事务日志"], "视图的关键词是“虚拟表”，常见价值是简化查询、控制权限和隐藏复杂性。"),
    BASE.objective("scenario", "数据库", ["E-R 模型", "联系类型"], "需要表达一个学生可选多门课，一门课也可被多个学生选择", "建模为多对多联系，并通常通过关联实体或中间表实现", ["强行改成一对一关系", "删除课程实体只保留学生实体", "把关系信息写进备注字段"], "E-R 题核心是识别基数关系，多对多通常要落到关联实体或中间表。"),
    BASE.objective("definition", "网络", ["CDN", "内容分发"], "CDN", "通过将内容分发到靠近用户的边缘节点来降低访问延迟和源站压力", ["专门负责数据库主从同步", "用于描述内存分页算法", "只在局域网文件共享中使用"], "CDN 常考两个关键词：边缘分发和回源，题目里看到加速静态内容基本就能对上。"),
    BASE.objective("purpose", "网络", ["VPN", "远程接入"], "VPN", "在公用网络上建立受保护的逻辑专用通信通道", ["让所有外部请求绕过认证", "替代应用层权限模型", "只用于压缩图片资源"], "VPN 的重点是“逻辑专网”和“安全传输”，并不等同于所有安全问题都解决了。"),
    BASE.objective("definition", "安全架构", ["数字证书", "PKI"], "数字证书", "由可信机构签发并用于证明公钥归属与主体身份的电子凭证", ["专门保存数据库备份副本", "表示接口调用频率限制", "用于记录服务器磁盘空间"], "证书题要抓住“公钥绑定身份”，它和口令、令牌、日志不是一个层面的东西。"),
    BASE.objective("purpose", "安全架构", ["RBAC", "权限治理"], "RBAC", "通过角色聚合权限以降低授权管理复杂度并提升权限治理一致性", ["让每位用户都直接配置全部权限", "替代日志审计平台", "只用于加密存储字段"], "RBAC 适合权限相对稳定的组织场景，核心是“角色承载权限，用户关联角色”。"),
    BASE.objective("definition", "项目管理", ["关键路径", "进度控制"], "关键路径", "决定项目总工期且时差为零或最小的活动路径", ["预算最高的活动集合", "风险等级最低的任务链路", "只包含外包任务的执行顺序"], "关键路径考的是工期控制，不是成本控制；哪个路径一延误就拖整体，那个通常就是关键路径。"),
    BASE.objective("purpose", "项目管理", ["MoSCoW", "需求优先级"], "MoSCoW 优先级法", "按必须有、应该有、可以有和本次暂不实施来排序需求优先级", ["把需求按开发人员喜好排序", "只根据代码改动行数决定优先级", "要求所有需求都归为最高优先级"], "优先级题最怕“一刀切”，MoSCoW 的价值就是帮助范围和节奏做取舍。"),
]


CASE_STUDIES = [
    {
        "category": "系统规划与分析",
        "knowledgePoints": ["现状调研", "立项评估", "实施路径"],
        "stem": "某企业计划整合多个历史系统建设统一业务平台，但部门诉求差异大、预算有限且原系统复杂。请从系统规划与分析角度给出架构方案。",
        "focus": "现状调研、可行性分析、范围划分、收益评估、阶段路径、风险识别和治理机制",
        "hint": "规划先行与分阶段落地",
    },
    {
        "category": "工作流",
        "knowledgePoints": ["流程引擎", "规则外置", "流程治理"],
        "stem": "某集团审批流程多且调整频繁，流程规则散落在多个系统代码中，导致变更周期长。请分析工作流平台化建设思路。",
        "focus": "流程建模、规则外置、表单集成、流程引擎、权限控制、审计追踪和版本治理",
        "hint": "流程外置与治理闭环",
    },
    {
        "category": "数据库",
        "knowledgePoints": ["读写分离", "分区归档", "事务控制"],
        "stem": "某交易平台随着业务增长出现慢查询增多、历史数据膨胀和锁冲突频发。请从数据库架构角度提出改进方案。",
        "focus": "索引优化、SQL 治理、事务边界、冷热分层、读写分离、容量扩展和监控预警",
        "hint": "结构优化与容量治理",
    },
    {
        "category": "WEB 应用",
        "knowledgePoints": ["缓存分层", "高并发", "安全控制"],
        "stem": "某门户系统在活动高峰期间出现静态资源加载慢、登录失败重试增多和接口波动等问题。请分析 Web 应用整体优化方案。",
        "focus": "静动态分离、缓存分层、会话治理、限流降级、鉴权安全、容量评估和可观测性",
        "hint": "性能与稳定性双线治理",
    },
    {
        "category": "安全架构",
        "knowledgePoints": ["零信任", "终端接入", "动态授权"],
        "stem": "某政企办公平台面向多地分支与外部协作单位开放，传统内网边界防护模式已难以满足要求。请分析零信任安全架构方案。",
        "focus": "身份治理、设备准入、动态授权、访问审计、细粒度策略、高可用和运维协同",
        "hint": "持续验证与最小权限",
    },
    {
        "category": "软件架构设计",
        "knowledgePoints": ["质量属性", "架构评估", "优化闭环"],
        "stem": "某核心业务系统经过多轮需求迭代后，性能、可维护性和扩展性持续下降。请从软件架构评估与优化角度提出治理思路。",
        "focus": "质量属性、场景分析、风险识别、改进方案、验证指标、演进路径和复盘机制",
        "hint": "质量属性与权衡分析",
    },
]


ESSAYS = [
    {
        "category": "系统规划与分析",
        "knowledgePoints": ["业务调研", "范围控制", "实施路线"],
        "stem": "请结合实际项目，论述系统规划与分析在大型信息化建设中的应用实践，重点说明现状分析、范围界定和实施路线设计。",
        "focus": "现状调研、范围控制、可行性分析、路线规划和风险控制",
    },
    {
        "category": "数据治理",
        "knowledgePoints": ["统一口径", "数据质量", "治理组织"],
        "stem": "请结合实际项目，论述企业数据治理体系建设与应用实践，重点说明口径统一、质量治理和组织协同机制。",
        "focus": "指标口径、质量规则、元数据、权限分层和组织协同",
    },
    {
        "category": "软件架构设计",
        "knowledgePoints": ["架构评估", "质量属性", "持续优化"],
        "stem": "请结合实际项目，论述软件架构评估与持续优化实践，重点说明质量属性、权衡分析和优化闭环。",
        "focus": "质量属性、场景分析、风险识别、改进闭环和验证机制",
    },
]


OBJECTIVE_BANK = list(BASE.OBJECTIVE_BANK) + list(EXTENSION.OBJECTIVE_EXTENSION) + ADDITIONAL_OBJECTIVES


def build_objective_questions(start_id: int):
    questions = []
    next_id = start_id

    for entry_index, entry in enumerate(OBJECTIVE_BANK):
        templates = OBJECTIVE_TEMPLATES[entry["mode"]]
        for variant_index, template in enumerate(templates):
            year = YEARS[(entry_index * 2 + variant_index) % len(YEARS)]
            correct_index = (entry_index * 7 + variant_index) % 4
            options = entry["wrongs"][:]
            options.insert(correct_index, entry["correct"])

            questions.append(
                {
                    "id": next_id,
                    "year": year,
                    "stage": "上午芝士扩容",
                    "type": "singleChoice",
                    "category": entry["category"],
                    "knowledgePoints": entry["knowledgePoints"],
                    "stem": template.format(value=entry["term_or_scenario"]),
                    "options": [
                        {"id": label, "label": label, "content": content}
                        for label, content in zip(OPTION_LABELS, options)
                    ],
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

    for index, entry in enumerate(CASE_STUDIES):
        questions.append(
            {
                "id": next_id,
                "year": YEARS[index % len(YEARS)],
                "stage": "下午案例芝士扩容",
                "type": "caseStudy",
                "category": entry["category"],
                "knowledgePoints": entry["knowledgePoints"],
                "stem": entry["stem"],
                "options": [],
                "correctAnswers": [f"可从{entry['focus']}等方面展开。"],
                "analysis": f"这类案例题建议按“背景—问题—方案—落地—收益”组织答案，重点写清{entry['hint']}。",
                "score": 25,
                "estimatedMinutes": 20,
            }
        )
        next_id += 1

    return questions, next_id


def build_essay_questions(start_id: int):
    questions = []
    next_id = start_id

    for index, entry in enumerate(ESSAYS):
        questions.append(
            {
                "id": next_id,
                "year": YEARS[index % len(YEARS)],
                "stage": "论文题芝士扩容",
                "type": "essay",
                "category": entry["category"],
                "knowledgePoints": entry["knowledgePoints"],
                "stem": entry["stem"],
                "options": [],
                "correctAnswers": ["建议从项目背景、建设目标、总体方案、关键机制、实施效果和经验反思等方面展开。"],
                "analysis": f"论文题不要空谈概念，建议把{entry['focus']}放进真实项目脉络，并写出取舍与复盘。",
                "score": 75,
                "estimatedMinutes": 45,
            }
        )
        next_id += 1

    return questions


def main():
    if len(OBJECTIVE_BANK) != 75:
        raise RuntimeError(f"目标客观题源应为 75 组，当前为 {len(OBJECTIVE_BANK)} 组。")

    objective_questions, next_id = build_objective_questions(START_ID)
    case_questions, next_id = build_case_questions(next_id)
    essay_questions = build_essay_questions(next_id)

    questions = objective_questions + case_questions + essay_questions

    if len(objective_questions) != 1200:
        raise RuntimeError(f"目标客观题应为 1200 道，当前为 {len(objective_questions)} 道。")
    if len(case_questions) != 6:
        raise RuntimeError(f"目标案例题应为 6 道，当前为 {len(case_questions)} 道。")
    if len(essay_questions) != 3:
        raise RuntimeError(f"目标论文题应为 3 道，当前为 {len(essay_questions)} 道。")
    if len(questions) != 1209:
        raise RuntimeError(f"目标总题量应为 1209 道，当前为 {len(questions)} 道。")

    OUTPUT_PATH.write_text(json.dumps(questions, ensure_ascii=False, indent=2), encoding="utf-8")

    print(
        "generated cheko boost pack:",
        f"objective={len(objective_questions)}",
        f"case={len(case_questions)}",
        f"essay={len(essay_questions)}",
        f"total={len(questions)}",
        f"path={OUTPUT_PATH}",
    )


if __name__ == "__main__":
    main()
