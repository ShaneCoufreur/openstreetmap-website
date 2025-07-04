require "application_system_test_case"

class IssuesTest < ApplicationSystemTestCase
  include IssuesHelper

  def test_view_issues_not_logged_in
    visit issues_path

    within_content_heading do
      assert_content "Log In"
    end
  end

  def test_view_issues_normal_user
    sign_in_as(create(:user))

    visit issues_path
    assert_content "Forbidden"
  end

  def test_view_no_issues
    sign_in_as(create(:moderator_user))

    visit issues_path
    assert_content I18n.t("issues.page.issues_not_found")
  end

  def test_view_issues
    sign_in_as(create(:moderator_user))
    issues = create_list(:issue, 3, :assigned_role => "moderator")

    visit issues_path
    assert_content issues.first.reported_user.display_name
  end

  def test_view_issue_with_report
    sign_in_as(create(:moderator_user))
    issue = create(:issue, :assigned_role => "moderator")
    issue.reports << create(:report, :details => "test report text **with kramdown**")

    visit issue_path(issue)
    assert_content I18n.t("issues.show.reports", :count => 1)
    assert_content "test report text with kramdown"
    assert_selector "strong", :text => "with kramdown"
  end

  def test_view_issue_rich_text_container
    sign_in_as(create(:moderator_user))
    issue = create(:issue, :assigned_role => "moderator")
    issue.reports << create(:report, :details => "paragraph one\n\n---\n\nparagraph two")

    visit issue_path(issue)
    assert_content I18n.t("issues.show.reports", :count => 1)
    richtext = find "div.richtext"
    richtext_elements = richtext.all "*"
    assert_equal 3, richtext_elements.size
    assert_equal "p", richtext_elements[0].tag_name
    assert_equal "paragraph one", richtext_elements[0].text
    assert_equal "hr", richtext_elements[1].tag_name
    assert_equal "p", richtext_elements[2].tag_name
    assert_equal "paragraph two", richtext_elements[2].text
  end

  def test_view_issues_with_no_reported_user
    sign_in_as(create(:moderator_user))
    anonymous_note = create(:note_with_comments)
    issue = create(:issue, :reportable => anonymous_note, :assigned_role => "moderator")

    visit issues_path
    assert_content reportable_title(anonymous_note)

    visit issue_path(issue)
    assert_content reportable_title(anonymous_note)
  end

  def test_search_issues_by_user
    good_user = create(:user)
    bad_user = create(:user)
    create(:issue, :reportable => bad_user, :reported_user => bad_user, :assigned_role => "administrator")

    sign_in_as(create(:administrator_user))

    # No issues against the user
    visit issues_path
    fill_in "search_by_user", :with => good_user.display_name
    click_on "Search"
    assert_no_content I18n.t("issues.page.user_not_found")
    assert_content I18n.t("issues.page.issues_not_found")

    # User doesn't exist
    visit issues_path
    fill_in "search_by_user", :with => "Nonexistent User"
    click_on "Search"
    assert_content I18n.t("issues.page.user_not_found")
    assert_no_content I18n.t("issues.page.issues_not_found")

    # Find Issue against bad_user
    visit issues_path
    fill_in "search_by_user", :with => bad_user.display_name
    click_on "Search"
    assert_no_content I18n.t("issues.page.user_not_found")
    assert_no_content I18n.t("issues.page.issues_not_found")
  end

  def test_commenting
    issue = create(:issue, :assigned_role => "moderator")
    sign_in_as(create(:moderator_user))

    visit issue_path(issue)

    fill_in :issue_comment_body, :with => "test comment"
    click_on "Add Comment"
    assert_content I18n.t("issue_comments.create.comment_created")
    assert_content "test comment"

    issue.reload
    assert_equal("test comment", issue.comments.first.body)
  end

  def test_reassign_issue_to_moderators
    issue = create(:issue, :assigned_role => "administrator")
    sign_in_as(create(:administrator_user))

    visit issue_path(issue)

    assert_unchecked_field "Reassign Issue to Moderators"
    fill_in :issue_comment_body, :with => "reassigning to moderators"
    check "Reassign Issue to Moderators"
    click_on "Add Comment"

    assert_content "and the issue was reassigned"
    assert_current_path issues_path(:status => "open")

    issue.reload
    assert_equal "moderator", issue.assigned_role
  end

  def test_reassign_issue_to_administrators
    issue = create(:issue, :assigned_role => "moderator")
    sign_in_as(create(:moderator_user))

    visit issue_path(issue)

    assert_unchecked_field "Reassign Issue to Administrators"
    fill_in :issue_comment_body, :with => "reassigning to administrators"
    check "Reassign Issue to Administrators"
    click_on "Add Comment"

    assert_content "and the issue was reassigned"
    assert_current_path issues_path(:status => "open")

    issue.reload
    assert_equal "administrator", issue.assigned_role
  end

  def test_reassign_issue_as_super_user
    issue = create(:issue)
    sign_in_as(create(:super_user))

    visit issue_path(issue)

    fill_in :issue_comment_body, :with => "reassigning to moderators"
    check "Reassign Issue to Moderators"
    click_on "Add Comment"

    assert_content "and the issue was reassigned"
    assert_current_path issue_path(issue)
  end

  def test_issue_index_with_multiple_roles
    user1 = create(:user)
    user2 = create(:user)
    issue1 = create(:issue, :reportable => user1, :assigned_role => "administrator")
    issue2 = create(:issue, :reportable => user2, :assigned_role => "moderator")

    user = create(:administrator_user)
    create(:user_role, :user => user, :role => "moderator")
    sign_in_as(user)

    visit issues_path

    assert_link I18n.t("issues.page.reports_count", :count => issue1.reports_count), :href => issue_path(issue1)
    assert_link I18n.t("issues.page.reports_count", :count => issue2.reports_count), :href => issue_path(issue2)
  end

  def test_issues_pagination
    1.upto(8).each do |n|
      user = create(:user, :display_name => "extra_#{n}")
      create(:issue, :reportable => user, :reported_user => user, :assigned_role => "administrator")
    end

    sign_in_as(create(:administrator_user))

    visit issues_path(:limit => 5)

    # First Page
    assert_no_content I18n.t("issues.page.user_not_found")
    assert_no_content I18n.t("issues.page.issues_not_found")
    4.upto(8).each do |n|
      assert_content(/extra_#{n}[^\d]/i, :count => 2)
    end
    1.upto(3).each do |n|
      assert_no_content(/extra_#{n}[^\d]/i)
    end

    # Second Page
    click_on "Older Issues", :match => :first
    assert_no_content I18n.t("issues.page.user_not_found")
    assert_no_content I18n.t("issues.page.issues_not_found")
    4.upto(8).each do |n|
      assert_no_content(/extra_#{n}[^\d]/i)
    end
    1.upto(3).each do |n|
      assert_content(/extra_#{n}[^\d]/i, :count => 2)
    end

    # Back to First Page
    click_on "Newer Issues", :match => :first
    assert_no_content I18n.t("issues.page.user_not_found")
    assert_no_content I18n.t("issues.page.issues_not_found")
    4.upto(8).each do |n|
      assert_content(/extra_#{n}[^\d]/i, :count => 2)
    end
    1.upto(3).each do |n|
      assert_no_content(/extra_#{n}[^\d]/i)
    end
  end

  def test_single_issue_reporters
    sign_in_as(create(:moderator_user))
    issue = create(:issue, :assigned_role => "moderator")
    issue.reports << create(:report, :user => create(:user, :display_name => "Test Name"))

    visit issues_path
    assert_content issue.reported_user.display_name
    assert_content issue.reports.first.user.display_name
  end

  def test_multiple_issue_reporters
    sign_in_as(create(:moderator_user))
    issue = create(:issue, :assigned_role => "moderator")

    create_list(:report, 5, :issue => issue)

    visit issues_path
    0.upto(1).each do |n|
      assert_no_content issue.reports[n].user.display_name
    end
    2.upto(4).each do |n|
      assert_content issue.reports[n].user.display_name
    end
  end

  def test_ordering_issue_reporters
    sign_in_as(create(:moderator_user))
    issue = create(:issue, :assigned_role => "moderator")

    create_list(:report, 5, :issue => issue)

    4.downto(0).each do |n|
      issue.reports << create(:report, :user => issue.reports[n].user)
    end

    visit issues_path
    0.upto(2).each do |n|
      assert_content issue.reports[n].user.display_name
    end
    3.upto(4).each do |n|
      assert_no_content issue.reports[n].user.display_name
    end
  end

  def test_view_managed_issue
    issue = create(:issue, :assigned_role => "moderator")
    issue.reports << create(:report)
    moderator_user = create(:moderator_user)

    sign_in_as(moderator_user)
    visit issues_path

    within_content_body do
      assert_no_link moderator_user.display_name

      click_on "1 Report"
    end

    within_content_heading do
      assert_content "Open Issue ##{issue.id}"

      click_on "Resolve"

      assert_content "Resolved Issue ##{issue.id}"
    end

    visit issues_path

    within_content_body do
      assert_link moderator_user.display_name
    end
  end
end
