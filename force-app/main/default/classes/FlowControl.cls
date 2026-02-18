public class FlowControl {
  // Use this flag to control flow execution during tests
  private static Boolean bypassFlows = false;

  // Method to set the bypassFlows flag
  public static void setBypassFlows(Boolean value) {
    bypassFlows = value;
  }

  // Method to check if flows should be bypassed
  public static Boolean shouldBypassFlows() {
    return Test.isRunningTest() && bypassFlows;
  }
}
