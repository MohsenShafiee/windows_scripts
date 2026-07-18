#Requires AutoHotkey v2.0

class SwapService {
    __New(config, logger, windowService) {
        this.config := config
        this.logger := logger
        this.windows := windowService
    }

    ApplyCurrentSwap(currentSnapshot, monitorMap, operationId) {
        plan := this.windows.BuildSwapPlan(currentSnapshot, monitorMap)
        result := this.windows.ApplyPlan(plan, this.config.GetBool("General", "UseAtomicWindowMove", true))
        allowedPercent := this.config.GetInt("General", "MaxMoveFailurePercent", 25)
        failurePercent := plan.Length = 0 ? 0 : Round(result.failed * 100 / plan.Length)
        this.logger.Info("Current-content swap moved=" result.moved " failed=" result.failed
            " skipped=" result.skipped, operationId)
        if result.failed > 0
            this.logger.Warn("Some windows rejected the move; failurePercent=" failurePercent, operationId)
        if result.failed > 0 && failurePercent > allowedPercent
            throw Error("Too many window moves failed (" failurePercent "%)")
        this.windows.VerifyPlan(plan, this.config.GetInt("General", "GeometryTolerancePx", 5))
        return plan
    }

}
