@isTest
public class fatalException_test {
  static testMethod void fatalException_test() {
    fatalException excp = new fatalException('Invalid event ID');
    System.assert(excp.getMessage() != null);
  }

  static testMethod void fatalException2_test() {
    try {
      throw new fatalException('Testing');
    } catch (fatalException e) {
      System.assert(e.getMessage() != null);
    }
  }

  static testMethod void testCoverage() {
    fatalException fe = new fatalException('test');
    fe.testCoverage();
  }
}
