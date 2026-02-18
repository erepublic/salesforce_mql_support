@isTest(SeeAlldata=true)
public class event_logistics_controller_test {
  public static testMethod void test() {
    Test.StartTest();
    /*
			PageReference pageRef = Page.event_logistics_by_year; // Add your VF page Name here
			pageRef.getParameters().put('brand', 'GOVTECH');
			pageRef.getParameters().put('year','2017');
			Test.setCurrentPage(pageRef);
*/
    Test.setCurrentPage(new PageReference('apex/event_logistics_by_year'));
    ApexPages.currentPage().getParameters().put('brand', 'GOVERNING');
    ApexPages.currentPage().getParameters().put('year', '2017');

    event_logistics_controller contr = new event_logistics_controller();
    String brand = contr.brand_name;
    System.debug('brand: ' + brand);
    System.Assert(brand == 'Governing');
    Test.StopTest();
  }
}
