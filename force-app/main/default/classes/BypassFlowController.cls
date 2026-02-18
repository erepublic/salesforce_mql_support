public with sharing class BypassFlowController {
  @InvocableMethod(label='Check Bypass Condition')
  public static List<BypassResult> checkBypassCondition(
    List<String> inputParams
  ) {
    // Perform your logic to determine if the flow should be bypassed
    Boolean shouldBypass = FlowControl.shouldBypassFlows();

    List<BypassResult> results = new List<BypassResult>();
    results.add(new BypassResult(shouldBypass));
    return results;
  }

  public class BypassResult {
    @InvocableVariable(label='Should Bypass?')
    public Boolean shouldBypass;

    public BypassResult(Boolean shouldBypass) {
      this.shouldBypass = shouldBypass;
    }
  }
}
