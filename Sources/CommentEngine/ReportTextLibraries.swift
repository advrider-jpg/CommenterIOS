import Foundation

struct ReportFlagDefinition: Equatable, Sendable {
    enum Polarity: Equatable, Sendable {
        case positive
        case development
    }

    var id: String
    var label: String
    var polarity: Polarity
    var sentences: [String]
}

let englishFocusTemplatesSingle = [
    "{HeShe} has shown particular strength in {tag}.",
    "In {tag}, {heshe} demonstrates solid understanding.",
    "{Name} has developed skills in {tag}."
]

let englishFocusTemplatesDouble = [
    "{HeShe} has shown strength in {tag1} and {tag2}.",
    "In particular, {heshe} demonstrates skill with {tag1} and {tag2}.",
    "{Name} has developed understanding in {tag1} and {tag2}."
]

let mathProficiencyTemplatesSingle = [
    "{HeShe} demonstrates strength in {prof}.",
    "{Name} shows solid skills in {prof}.",
    "In {prof}, {heshe} performs confidently."
]

let mathProficiencyTemplatesDouble = [
    "{HeShe} demonstrates strength in {prof1} and {prof2}.",
    "{Name} shows solid skills in both {prof1} and {prof2}.",
    "In {prof1} and {prof2}, {heshe} performs confidently."
]

let nextStepTemplatesSingle = [
    "A helpful next step for {Name} is to {goal}.",
    "Moving forward, {Name} will benefit from focusing on {goal}.",
    "{Name} is encouraged to work on {goal} as a next step.",
    "To continue progressing, {Name} should focus on {goal}."
]

let nextStepTemplatesDouble = [
    "Moving forward, {Name} is encouraged to {goal1} and {goal2}.",
    "Next steps for {Name} include {goal1} and {goal2}.",
    "To continue developing, {Name} will focus on {goal1} as well as {goal2}.",
    "{Name} is working towards {goal1} and {goal2}."
]

func mindsetToFragment(_ toggle: String) -> String {
    [
        "Growth mindset": "demonstrates a growth mindset",
        "Perseveres with challenge": "perseveres when faced with challenges",
        "Asks clarifying questions": "asks clarifying questions when needed",
        "Explains/justifies reasoning": "explains and justifies reasoning clearly",
        "Checks working carefully": "checks working carefully"
    ][toggle] ?? toggle.lowercased()
}

let reportFlags: [ReportFlagDefinition] = [
    ReportFlagDefinition(
        id: "TURN_TAKING_CALLING_OUT",
        label: "Turn-taking and calling out",
        polarity: .development,
        sentences: [
            "[StudentName] is encouraged to wait for a turn to speak during [Subject] discussions so that everyone can be heard.",
            "During [Subject], [StudentName] will benefit from raising a hand and waiting to be invited before contributing.",
            "To support focused learning in [Subject], [StudentName] is working on sharing ideas at appropriate times.",
            "A helpful next step for [StudentName] in [Subject] is to pause and listen before responding to others\u{2019} contributions.",
            "In [Subject] lessons, [StudentName] is learning to contribute thoughtfully without interrupting classmates.",
            "[StudentName] would make even stronger progress in [Subject] by waiting for instructions before calling out answers.",
            "In class discussions, [StudentName] is encouraged to allow others to finish speaking before adding ideas in [Subject].",
            "[StudentName] is developing respectful discussion habits in [Subject] by waiting to be called on before speaking.",
            "A goal for [StudentName] in [Subject] is to use agreed discussion signals rather than speaking over others.",
            "To improve lesson flow in [Subject], [StudentName] is working on turn-taking and listening cues."
        ]
    ),
    ReportFlagDefinition(
        id: "EXCESSIVE_TALKING_DISRUPTION",
        label: "Excessive talking and disruption",
        polarity: .development,
        sentences: [
            "[StudentName] is encouraged to reduce side conversations during [Subject] so they can maintain focus and complete tasks.",
            "In [Subject], [StudentName] is working on speaking at appropriate times so that learning is not interrupted.",
            "A next step for [StudentName] is to stay quiet during instruction time in [Subject] to support understanding.",
            "[StudentName] will benefit from using partner-talk moments in [Subject] rather than talking during teacher explanations.",
            "To help [Subject] lessons run smoothly, [StudentName] is working on limiting chatting and staying attentive.",
            "[StudentName] is encouraged to keep comments related to the task in [Subject] and save social talk for break times.",
            "During independent work in [Subject], [StudentName] is developing strategies to avoid distracting nearby students.",
            "In [Subject], [StudentName] can improve productivity by focusing on the task before engaging in conversations.",
            "A helpful goal for [StudentName] is to use a quiet voice and remain on-task during [Subject] learning time.",
            "[StudentName] is learning to manage talking so that they and others can make the most of [Subject] learning."
        ]
    ),
    ReportFlagDefinition(
        id: "ON_TASK_FOCUS",
        label: "Staying on-task and focused",
        polarity: .development,
        sentences: [
            "[StudentName] is encouraged to begin tasks promptly in [Subject] to make the most of learning time.",
            "In [Subject], [StudentName] will benefit from checking instructions carefully before starting work.",
            "A next step for [StudentName] is to maintain attention during [Subject] explanations and ask for clarification when needed.",
            "[StudentName] is working on sustaining focus in [Subject], particularly during independent tasks.",
            "In [Subject], [StudentName] is encouraged to use classroom routines (e.g., task lists) to stay on track.",
            "[StudentName] will make stronger progress in [Subject] by minimizing distractions and returning to the task quickly.",
            "During [Subject], [StudentName] is developing strategies to manage distractions and complete work within the lesson.",
            "A helpful goal for [StudentName] in [Subject] is to break tasks into smaller steps and tick them off as they go.",
            "[StudentName] is encouraged to stay engaged in [Subject] by contributing to discussions and attempting all set tasks.",
            "In [Subject], [StudentName] is working towards consistent concentration to improve overall task quality."
        ]
    ),
    ReportFlagDefinition(
        id: "WORK_COMPLETION_HOMEWORK",
        label: "Work completion and follow-through",
        polarity: .development,
        sentences: [
            "[StudentName] is encouraged to complete set work in [Subject] within the allocated time to demonstrate full understanding.",
            "A next step for [StudentName] is to submit [Subject] tasks on time and check that all parts have been attempted.",
            "In [Subject], [StudentName] will benefit from re-reading task requirements to ensure work is finished to the expected standard.",
            "[StudentName] is working on improving follow-through in [Subject] by completing classwork and any take-home learning consistently.",
            "To support progress in [Subject], [StudentName] is encouraged to finish tasks before moving on to new activities.",
            "[StudentName] can strengthen outcomes in [Subject] by completing practice work regularly and bringing it to class.",
            "In [Subject], [StudentName] is developing routines to keep track of deadlines and outstanding tasks.",
            "A helpful goal for [StudentName] is to use feedback to revise and improve [Subject] work before submission.",
            "[StudentName] is encouraged to ask for help early in [Subject] when unsure, rather than leaving tasks incomplete.",
            "With consistent task completion in [Subject], [StudentName] will be able to show more clearly what they know and can do."
        ]
    ),
    ReportFlagDefinition(
        id: "ORGANISATION_PREPAREDNESS",
        label: "Organisation and preparedness",
        polarity: .development,
        sentences: [
            "[StudentName] is encouraged to come prepared for [Subject] with the necessary materials so learning time is used effectively.",
            "A next step for [StudentName] is to keep [Subject] resources organised to support efficient task completion.",
            "[StudentName] will benefit from developing a routine for recording [Subject] homework and due dates.",
            "In [Subject], [StudentName] is working on improving organisation by maintaining a tidy workspace and clear notes.",
            "To support success in [Subject], [StudentName] is encouraged to check their schedule and pack required items each day.",
            "[StudentName] is developing better time-management in [Subject] by planning steps and allocating time to each part of a task.",
            "A helpful goal for [StudentName] is to file and label [Subject] work so it can be easily accessed for revision.",
            "[StudentName] can strengthen [Subject] learning by keeping their book up to date and recording key ideas clearly.",
            "In [Subject], [StudentName] is encouraged to use checklists to stay organised and meet expectations.",
            "Improved organisation will help [StudentName] complete [Subject] tasks more confidently and independently."
        ]
    ),
    ReportFlagDefinition(
        id: "SELF_REGULATION_EMOTIONS",
        label: "Self-regulation and emotional control",
        polarity: .development,
        sentences: [
            "[StudentName] is developing strategies to manage frustration during [Subject] tasks and persist when work is challenging.",
            "In [Subject], [StudentName] is encouraged to use calming strategies and ask for support when feeling overwhelmed.",
            "A next step for [StudentName] is to respond respectfully to feedback in [Subject] and use it to improve their work.",
            "[StudentName] is working on staying calm and focused in [Subject], particularly when tasks require sustained effort.",
            "During [Subject], [StudentName] will benefit from pausing, breathing, and re-reading instructions when stuck.",
            "[StudentName] is encouraged to practise resilient learning behaviours in [Subject] by attempting multiple strategies before stopping.",
            "In [Subject], [StudentName] is learning to handle setbacks positively and continue working towards solutions.",
            "A helpful goal for [StudentName] is to use classroom support routines in [Subject] rather than disengaging when challenged.",
            "[StudentName] can strengthen progress in [Subject] by taking breaks appropriately and returning to tasks ready to learn.",
            "With support, [StudentName] is building self-management skills in [Subject] that will improve learning consistency."
        ]
    ),
    ReportFlagDefinition(
        id: "PARTICIPATION_ENGAGEMENT",
        label: "Participation and engagement",
        polarity: .positive,
        sentences: [
            "[StudentName] participates confidently in [Subject] and contributes thoughtful ideas during discussions.",
            "In [Subject], [StudentName] engages positively in learning activities and shows genuine interest in new concepts.",
            "[StudentName] demonstrates strong engagement in [Subject] by asking relevant questions and attempting challenges willingly.",
            "[StudentName] contributes meaningfully in [Subject] lessons and listens respectfully to others\u{2019} viewpoints.",
            "During [Subject], [StudentName] shows enthusiasm for learning and is keen to share understandings with the class.",
            "[StudentName] is an active participant in [Subject] and approaches tasks with a positive attitude.",
            "In [Subject], [StudentName] consistently engages with tasks and benefits from collaborating and sharing ideas.",
            "[StudentName] shows confidence in [Subject] discussions and supports a positive learning environment.",
            "[StudentName] demonstrates commitment in [Subject] by staying involved and making the most of learning opportunities.",
            "In [Subject], [StudentName] is engaged and motivated, which supports steady progress across the reporting period."
        ]
    ),
    ReportFlagDefinition(
        id: "COLLABORATION_RESPECT",
        label: "Collaboration and respect for others",
        polarity: .positive,
        sentences: [
            "[StudentName] works cooperatively in [Subject] and treats classmates with respect during group tasks.",
            "In [Subject], [StudentName] listens well to others and contributes positively to teamwork and discussion.",
            "[StudentName] demonstrates kindness and consideration in [Subject] by encouraging peers and sharing resources fairly.",
            "[StudentName] collaborates effectively in [Subject], valuing others\u{2019} ideas and helping the group stay focused.",
            "During [Subject], [StudentName] supports a respectful classroom climate through polite communication and positive interactions.",
            "[StudentName] works well with a range of peers in [Subject] and contributes to productive group outcomes.",
            "In [Subject], [StudentName] demonstrates respectful disagreement by explaining ideas calmly and listening to alternatives.",
            "[StudentName] shows strong interpersonal skills in [Subject] by negotiating roles and sharing responsibilities fairly.",
            "During group work in [Subject], [StudentName] helps maintain harmony and keeps the team moving forward.",
            "[StudentName] is a reliable collaborator in [Subject] and consistently contributes to a supportive learning environment."
        ]
    ),
    ReportFlagDefinition(
        id: "INITIATIVE_EXTENSION_CURIOSITY",
        label: "Initiative, curiosity and extension",
        polarity: .positive,
        sentences: [
            "[StudentName] shows initiative in [Subject] by seeking extension tasks and exploring ideas in greater depth.",
            "In [Subject], [StudentName] demonstrates curiosity by asking insightful questions and making connections to prior learning.",
            "[StudentName] frequently goes beyond the basics in [Subject], showing a desire to deepen understanding.",
            "[StudentName] takes responsibility for learning in [Subject] by independently researching or practising skills when needed.",
            "In [Subject], [StudentName] demonstrates strong initiative by starting tasks promptly and aiming for high-quality outcomes.",
            "[StudentName] approaches [Subject] with curiosity and regularly looks for ways to improve and refine work.",
            "[StudentName] shows a growth mindset in [Subject] by embracing challenges and learning from mistakes.",
            "In [Subject], [StudentName] often extends ideas through creative thinking, detailed explanations, or additional examples.",
            "[StudentName] demonstrates independence in [Subject] by planning steps carefully and checking work thoughtfully.",
            "Through consistent initiative in [Subject], [StudentName] is developing deeper understanding and stronger skills."
        ]
    ),
    ReportFlagDefinition(
        id: "LEADERSHIP_ROLE_MODEL_HELPFULNESS",
        label: "Leadership and positive influence",
        polarity: .positive,
        sentences: [
            "[StudentName] demonstrates leadership in [Subject] by supporting peers and modelling positive learning behaviours.",
            "In [Subject], [StudentName] is a positive role model who contributes to a respectful and productive classroom environment.",
            "[StudentName] shows leadership in [Subject] by helping others understand tasks and encouraging teamwork.",
            "During [Subject], [StudentName] contributes positively by taking responsibility and setting a strong example for peers.",
            "[StudentName] supports others in [Subject] by offering assistance appropriately and sharing strategies for success.",
            "In [Subject], [StudentName] demonstrates mature leadership by listening, guiding group work, and keeping tasks on track.",
            "[StudentName] positively influences the class in [Subject] through consistent effort and respectful communication.",
            "During [Subject], [StudentName] helps build a supportive learning culture by including others and celebrating progress.",
            "[StudentName] demonstrates responsibility in [Subject] and can be relied upon to contribute constructively to class routines.",
            "In [Subject], [StudentName] shows emerging leadership skills that strengthen both personal learning and group outcomes."
        ]
    )
]
