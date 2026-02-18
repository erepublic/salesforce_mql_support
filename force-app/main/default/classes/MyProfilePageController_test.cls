@isTest
public with sharing class MyProfilePageController_test {
  @IsTest(SeeAllData=true)
  static void testSave() {
    // Modify the test to query for a portal user that exists in your org
    List<User> existingPortalUsers = [
      SELECT id, profileId, userRoleId
      FROM User
      WHERE UserRoleId != NULL AND UserType = 'CustomerSuccess'
    ];

    if (existingPortalUsers.isEmpty()) {
      User currentUser = [
        SELECT
          id,
          title,
          firstname,
          lastname,
          email,
          phone,
          mobilephone,
          fax,
          street,
          city,
          state,
          postalcode,
          country
        FROM User
        WHERE id = :UserInfo.getUserId()
      ];
      MyProfilePageController controller = new MyProfilePageController();
      System.assertEquals(
        currentUser.Id,
        controller.getUser().Id,
        'Did not successfully load the current user'
      );
      System.assert(
        controller.isEdit == false,
        'isEdit should default to false'
      );
      controller.edit();
      System.assert(controller.isEdit == true);
      controller.cancel();
      System.assert(controller.isEdit == false);

      Contact c = testData.createContact();

      MyProfilePageController.setContactFields(c, currentUser);
      controller.save();
      System.assert(
        Page.ChangePassword.getUrl()
          .equals(controller.changePassword().getUrl())
      );
    } else {
      User existingPortalUser = existingPortalUsers[0];
      String randFax = Math.rint(Math.random() * 1000) + '5551234';

      System.runAs(existingPortalUser) {
        MyProfilePageController controller = new MyProfilePageController();
        System.assertEquals(
          existingPortalUser.Id,
          controller.getUser().Id,
          'Did not successfully load the current user'
        );
        System.assert(
          controller.isEdit == false,
          'isEdit should default to false'
        );
        controller.edit();
        System.assert(controller.isEdit == true);

        controller.cancel();
        System.assert(controller.isEdit == false);

        controller.getUser().Fax = randFax;
        controller.save();
        System.assert(controller.isEdit == false);
      }

      // verify that the user and contact were updated
      existingPortalUser = [
        SELECT id, fax, Contact.Fax
        FROM User
        WHERE id = :existingPortalUser.Id
      ];
      System.assert(existingPortalUser.fax == randFax);
      System.assert(existingPortalUser.Contact.fax == randFax);
    }
  }
}
