local Deployment = require("data.agent_deployment_defaults")
return {
    done = { id = "done", label = "DONE", width = 89, height = 21,
        basePath = "assets/images/ui_elements/done_btn_false.png", hoverPath = "assets/images/ui_elements/done_btn_true.png" },
    nextPhase = { id = "next_phase", label = "NEXT PHASE", width = 89, height = 21,
        basePath = "assets/images/ui_elements/nextphase_btn_false.png", hoverPath = "assets/images/ui_elements/nextphase_btn_true.png" },
    actionsSpent = { text = "ALL ACTIONS SPENT", color = { 1, 68 / 255, 68 / 255, 1 }, gap = 4 },
    defeatedLabel = "DEFEATED", allDefeatedPrompt = "ALL AGENTS\nDEFEATED",
    doneGap = 6, nextPhaseGap = 8, returnDuration = 0.12,
    exhaustedBrightness = 0.5, badgeColor = Deployment.assignedColor,
    allExhaustedPrompt = "ALL AGENTS\nEXHAUSTED",
}
