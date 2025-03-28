require "application_system_test_case"

class ReportNoteTest < ApplicationSystemTestCase
  def test_no_link_when_not_logged_in
    note = create(:note_with_comments)
    visit note_path(note)
    assert_content note.description

    assert_no_content I18n.t("notes.show.report")
  end

  def test_can_report_anonymous_notes
    note = create(:note_with_comments)
    sign_in_as(create(:user))
    visit note_path(note)

    click_on I18n.t("notes.show.report")
    assert_content "Report"
    assert_content I18n.t("reports.new.disclaimer.intro")

    choose I18n.t("reports.new.categories.note.spam_label")
    fill_in "report_details", :with => "This is spam"
    assert_difference "Issue.count", 1 do
      click_on "Create Report"
    end

    assert_content "Your report has been registered successfully"

    assert_equal note, Issue.last.reportable
    assert_equal "moderator", Issue.last.assigned_role
  end

  def test_can_report_notes_with_author
    user = create(:user)
    note = create(:note_comment, :author => user, :note => build(:note, :author => user)).note
    sign_in_as(create(:user))
    visit note_path(note)

    click_on I18n.t("notes.show.report")
    assert_content "Report"
    assert_content I18n.t("reports.new.disclaimer.intro")

    choose I18n.t("reports.new.categories.note.spam_label")
    fill_in "report_details", :with => "This is spam"
    assert_difference "Issue.count", 1 do
      click_on "Create Report"
    end

    assert_content "Your report has been registered successfully"

    assert_equal note, Issue.last.reportable
    assert_equal "moderator", Issue.last.assigned_role
  end
end
