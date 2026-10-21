# Aura notice — wording and kind of every former snackbar (1.7.0)

For the founder's review. Built 21 Oct 2026 on `feat/aura-notice` from the approved spec (amended the same day: each platform's own convention). Every `showSnackBar` call in `lib/` now goes through `AuraNotice` (`lib/core/ui/aura_notice.dart`); a guard test refuses any new one.

**House style applied by the notice itself:** a message that does not end in `.`, `!`, `?`, `…`, `)` or a closing quote gets a full stop. A new notice replaces the old one, so explicit `hideCurrentSnackBar`/`clearSnackBars` calls before a show were removed.

**Kinds:** every "… copied." row listed as done goes through `AuraNotice.copied`. done = ✓ gold, 4 s · info = ⓘ, 4 s · problem = ! red, 6 s with ×. `copied` = done, except on Android 13+ where the system's own clipboard confirmation is the only one.

## Removed (shown only when something actually happened)

1. Post composer: the second publish notice ("Your discussion is live.") replaced the first ("Published to Aura.") immediately; there is now one.
2. Saving media: no notice when the person dismisses the save dialog themselves.
3. Copy confirmations on Android 13+ (API 33+): Android already says "Copied to clipboard."
4. Notices built from raw error text: replaced, not removed (see below).

## Sites rewritten by hand

| File | Kind | Before | After |
|---|---|---|---|
| `lib/core/eligibility/eligibility_affordance.dart` (_tell) | problem | refusal message, 6 s | (unchanged words; now a problem notice) |
| `lib/core/errors/app_error_ui.dart` | problem | `AppErrorUi.showSnackBar` (no callers) | renamed `showNotice`, routes to AuraNotice with its action |
| `lib/core/media/aura_attachment_open.dart` (_tell) | problem | `This attachment could not be opened.` / `No app on this device can open this file.` | (unchanged) |
| `lib/core/media/aura_media_viewer.dart` (_toast) | problem | media not available messages | (unchanged) |
| `lib/core/media/media_save_button.dart` | by result | `result.message` (always shown) | done when saved, problem when failed, info when handed to the browser; **nothing when the person cancelled the save dialog** |
| `lib/core/translation/communication_translate_action.dart` | problem | `appError.message` + Sign in | (unchanged) |
| `lib/features/announcements/presentation/announcement_editor_screen.dart` (publish) | done / problem | `Announcement published to X. TikTok (<raw error>) could not be queued.` | `Announcement published to X. It was not shared to TikTok. Try again from the announcement.` (raw errors removed from LinkedIn, Facebook, Instagram, TikTok; logged instead) |
| `lib/features/articles/presentation/article_editor_screen.dart` (publish) | problem | `An article is substantial authored thought — write a little more before publishing.` / `Could not publish — a title and a substantial body are required.` | `An article is substantial authored thought. Write a little more, then publish.` / `The article was not published. Add a title and a full body, then try again.` |
| `lib/features/institutions/domain/institution_domains_screen.dart` | mixed | `Domain verified successfully.` / `DNS record not found.` | `Domain verified.` / `The DNS record was not found yet. Check it and try again.` |
| ″ | problem | `Could not add domain.` / `Could not remove domain.` / `Could not issue DNS challenge.` / `Could not verify domain.` | `The domain was not added. Try again.` / `The domain was not removed. Try again.` / `The DNS record to add was not created. Try again.` / `The domain was not verified. Try again.` |
| ″ | info | `Auto verify started. Checking every 30 seconds.` | `Checking the domain every 30 seconds.` |
| ″ | copied | `$label copied.` | (unchanged; silent on Android 13+) |
| `lib/features/institutions/engagement/question_record.dart` | problem | `Could not acknowledge it just now.` / `The date could not be changed just now.` | `It was not acknowledged. Try again.` / `The date was not changed. Try again.` |
| `lib/features/institutions/units/institution_units_screen.dart` | problem | raw `e.toString()` fallback | `That did not go through. Try again.` |
| `lib/features/me/presentation/me_screen.dart` | done / problem | `LinkedIn flow finished.` | `LinkedIn is not connected. You can try again.` |
| ″ | — | any server-less error showed Dio's own message | shows the plain fallback instead |
| ″ | problem | `Could not disconnect LinkedIn.` / `Could not refresh TikTok connection.` / `Could not disconnect TikTok.` | `LinkedIn was not disconnected. Try again.` / `The TikTok connection was not refreshed. Try again.` / `TikTok was not disconnected. Try again.` |
| `lib/features/me/presentation/widgets/facebook_page_connection.dart` | info | `Facebook opened. Approve there, then choose your Page.` | `Facebook is open. Approve there, then choose your Page.` |
| ″ | problem | `Facebook could not be opened right now. Please try again.` / `Your Facebook Pages could not be loaded. Please try again.` / `That Page could not be chosen. Please try again.` / `Facebook could not be disconnected. Please try again.` / `Facebook did not connect.` | `Facebook did not open. Try again.` / `Your Facebook Pages did not load. Try again.` / `That Page was not chosen. Try again.` / `Facebook was not disconnected. Try again.` / `Facebook did not connect. Try again.` |
| `lib/features/meetings/presentation/create_meeting_screen.dart` | problem / copied | `Unable to create meeting. Try again.` / `Institution participants require an institution meeting.` / `Invitee copied` | `The meeting was not created. Try again.` / `Institution participants need an institution meeting.` / `Invitee copied.` |
| `lib/features/meetings/presentation/institution_availability_screen.dart` (6 sites) | problem | `Something went wrong. Try again.` ×5, `Error: <raw error>` | `The booking page was not updated. Try again.` / `The booking page was not deleted. Try again.` / `That time was not removed. Try again.` / `That time was not saved. Try again.` / `Your changes were not saved. Try again.` ×2 |
| `lib/features/meetings/presentation/pre_join_screen.dart` | problem | `Could not join: <msg>` / `Could not send code: <msg>` | `You did not join the meeting. <msg>` / `The code was not sent. <msg>` |
| `lib/features/posts/presentation/compose_screen.dart` | problem | `Could not hold this work: <msg>` | `Your draft was not saved. <msg>` |
| ″ | done / problem | `Published to Aura. TikTok (<msg>) could not be queued.` | `Published to Aura. It was not shared to TikTok. Try again from the post.` |
| ″ | done | `Reply published.` / `Published to Aura.` **then** `Your reply is live in the discussion.` / `Your discussion is live.` (two notices, the second replaced the first at once) | one notice: `Your reply is live in the discussion.` / `Your discussion is live.` |
| ″ | problem | `Published to Aura, but the screen could not finish cleanly: <detail>` | `Published to Aura. Reopen the post to check it.` |
| `lib/features/posts/presentation/widgets/post_card/post_card_utils.dart` | copied / info | `copyToClipboard` confirmations; link-open fallbacks used the same `Link copied` | pure copies use `copied` (silent on Android 13+); "the link did not open, so it was copied" fallbacks are info and always shown; default fallback `The link did not open, so it was copied.` |
| `lib/features/posts/presentation/widgets/post_card.dart` | problem | `Only institution speakers can react as institution.` / `Could not update like` / `Could not update save` / `Could not repost: <msg>` | `Only people who speak for the institution can react as it.` / `Your like was not saved. Try again.` / `It was not saved. Try again.` / `<msg>` (the plain mapped reason) |
| `lib/features/profile/presentation/author_profile_screen.dart` | mixed | `Profile is not available for messaging.` / `Could not open message thread.` / `Request canceled` / `Follow request sent` / `Could not update follow state` / `User blocked. A moderator will review within 24 hours.` / `Could not block user. Try again later.` | `This person cannot be messaged.` / `The conversation did not open. Try again.` / `Follow request cancelled.` / `Follow request sent.` / `Your follow was not updated. Try again.` / `Blocked. A moderator reviews it within 24 hours.` / `This person was not blocked. Try again.` |
| `lib/features/profile/presentation/follow_requests_screen.dart` | mixed | `Follow request accepted` / `Could not accept follow request` / `Follow request declined` / `Could not decline follow request` | `Follow request accepted.` / `The follow request was not accepted. Try again.` / `Follow request declined.` / `The follow request was not declined. Try again.` |
| `lib/features/share/presentation/share_screen.dart` | mixed | `That file could not be added.` | `That file was not added. Try another.` |
| `lib/widgets/note_card.dart` | info / done | `Login required` / `Bookmarked` / `Removed` (0.9 s) | `Sign in to do that.` / `Saved.` / `Removed from saved.` (4 s) |
| `lib/features/invite_to_aura/invite_to_aura.dart` | info | after-post offer, 8 s, shown over the publish line | same words, 4 s, waits for the publish line to finish; opens its sheet from the root navigator |
| ″ | info | `Sharing is unavailable; invite link copied` | `Sharing did not open, so your invite link was copied.` |
| `lib/core/notifications/notification_bridge.dart` (×2) | info | `title — body` | (unchanged) |

## Sites rewritten mechanically (original line in rc/1.7.0 eec3ad0c)

| File:line | Kind | Before | After |
|---|---|---|---|
| `lib/app/shell/member_shell.dart:552` | done | `'Public URL copied'` | `'Public link copied.'` |
| `lib/app/shell/member_shell.dart:561` | info | `'Open in new tab: $link'` | `'Link copied. Open it in a new tab: $link'` |
| `lib/core/compliance/report_block_menu.dart:98` | done | `'Blocked.'` | (unchanged) |
| `lib/core/compliance/report_block_menu.dart:103` | problem | `'Could not block. Try again later.'` | `'This person was not blocked. Try again.'` |
| `lib/core/compliance/report_content_sheet.dart:105` | done | `'Report submitted. A moderator will review within 24 hours.'` | `'Report sent. A moderator reviews reports within 24 hours.'` |
| `lib/core/engagement/aura_engagement_bar.dart:65` | problem | `err.message` | (unchanged) |
| `lib/core/engagement/aura_publication_discussion.dart:68` | problem | `err.message` | (unchanged) |
| `lib/core/media/aura_media_viewer.dart:125` | problem | `'The original media is not available.'` | `'The original is not available.'` |
| `lib/core/media/aura_media_viewer.dart:161` | info | `'$reason Link copied to the clipboard.'` | (unchanged) |
| `lib/core/media/media_save_button.dart:18` | info | `'Preparing download…'` | `'Preparing your download.'` |
| `lib/core/notifications/notification_bridge.dart:475` | info | `body.isEmpty ? title : '$title — $body'` | (unchanged) |
| `lib/core/notifications/notification_bridge.dart:629` | info | `body.isEmpty ? title : '$title — $body'` | (unchanged) |
| `lib/features/admin/areas/external_area_actions.dart:322` | problem | `_message(e)` | (unchanged) |
| `lib/features/admin/areas/external_area_actions.dart:471` | done | `'Copied'` | `'Copied.'` |
| `lib/features/admin/areas/subject_person_area.dart:327` | info | `'This person already holds every class.'` | (unchanged) |
| `lib/features/admin/areas/subject_person_area.dart:459` | problem | `'No institution could be read, so an affiliation cannot be named.'` | `'No institution could be read, so no affiliation can be named. Try again.'` |
| `lib/features/admin/presentation/admin_person_verification_sheet.dart:144` | problem | `'Verification update failed: $e'` | `'The verification was not updated. Try again.'` |
| `lib/features/ai/presentation/claim_audit_screen.dart:456` | done | `'Suggestion copied'` | `'Suggestion copied.'` |
| `lib/features/announcements/presentation/announcement_detail_screen.dart:257` | problem | `message` | (unchanged) |
| `lib/features/announcements/presentation/announcement_detail_screen.dart:354` | done | `pinned ? 'Pinned to the top.' : 'No longer pinned.'` | (unchanged) |
| `lib/features/announcements/presentation/announcement_detail_screen.dart:361` | problem | `'That did not go through. Try again.'` | (unchanged) |
| `lib/features/announcements/presentation/announcement_detail_screen.dart:408` | done | `'Unpublished.'` | (unchanged) |
| `lib/features/announcements/presentation/announcement_detail_screen.dart:411` | problem | `AppErrorMapper.from(e, feature: 'unpublish this').message` | (unchanged) |
| `lib/features/announcements/presentation/announcement_detail_screen.dart:439` | done | `'Draft deleted.'` | (unchanged) |
| `lib/features/announcements/presentation/announcement_detail_screen.dart:448` | problem | `AppErrorMapper.from(e, feature: 'remove this').message` | (unchanged) |
| `lib/features/announcements/presentation/announcement_editor_screen.dart:203` | problem | `'That announcement could not be opened.'` | (unchanged) |
| `lib/features/announcements/presentation/announcement_editor_screen.dart:219` | problem | `'That announcement could not be opened.'` | (unchanged) |
| `lib/features/announcements/presentation/announcement_editor_screen.dart:353` | problem | `refusals.join(String.fromCharCode(10))` | (unchanged) |
| `lib/features/articles/presentation/article_editor_screen.dart:127` | problem | `'Could not open the draft — try again.'` | `'The draft did not open. Try again.'` |
| `lib/features/articles/presentation/article_editor_screen.dart:296` | problem | `e is _CoverRefused ? e.message : 'Cover upload failed — try again.'` | `e is _CoverRefused ? e.message : 'The cover was not uploaded. Try again.'` |
| `lib/features/articles/presentation/article_editor_screen.dart:321` | problem | `'Could not remove the cover — try again.'` | `'The cover was not removed. Try again.'` |
| `lib/features/articles/presentation/article_editor_screen.dart:366` | done | `'Image added'` | `'Image added.'` |
| `lib/features/articles/presentation/article_editor_screen.dart:378` | problem | `e is _CoverRefused ? e.message : 'Image upload failed — try again.'` | `e is _CoverRefused ? e.message : 'The image was not uploaded. Try again.'` |
| `lib/features/articles/presentation/article_editor_screen.dart:400` | done | `'Restored. It is publicly visible again.'` | (unchanged) |
| `lib/features/articles/presentation/article_editor_screen.dart:408` | problem | `err.message` | (unchanged) |
| `lib/features/articles/presentation/article_screen.dart:288` | done | `'Retracted. You can restore it here.'` | (unchanged) |
| `lib/features/articles/presentation/article_screen.dart:295` | problem | `err.message` | (unchanged) |
| `lib/features/articles/presentation/article_screen.dart:343` | done | `'Reshared to your feed.'` | (unchanged) |
| `lib/features/articles/presentation/article_screen.dart:350` | problem | `err.message` | (unchanged) |
| `lib/features/communications/presentation/communications_center_screen.dart:76` | problem | `'Could not update communication settings. Please try again.'` | `'Your communication settings were not saved. Try again.'` |
| `lib/features/communications/presentation/widgets/admin_campaign_workflow.dart:90` | problem | `'Create or enter a draft id first.'` | `'Create a draft first, or enter an existing draft.'` |
| `lib/features/communications/presentation/widgets/admin_campaign_workflow.dart:117` | problem | `'Create or enter a draft id first.'` | `'Create a draft first, or enter an existing draft.'` |
| `lib/features/communications/presentation/widgets/admin_campaign_workflow.dart:145` | problem | `'Enter a draft id and recipient email first.'` | `'Enter a draft and a recipient email first.'` |
| `lib/features/communications/presentation/widgets/admin_campaign_workflow.dart:163` | done | `result.skipped ? 'Campaign test was skipped.' : 'Campaign test queued.'` | (unchanged) |
| `lib/features/communications/presentation/widgets/admin_newsletter_lab.dart:76` | problem | `'Enter a recipient email first.'` | (unchanged) |
| `lib/features/communications/presentation/widgets/admin_newsletter_lab.dart:98` | done | `result.skipped ? 'Newsletter test was suppressed.' : 'Newsletter test queued.'` | (unchanged) |
| `lib/features/communications/presentation/widgets/digest_preferences_panel.dart:69` | done | `'${_frequency.label} digest created or refreshed.'` | `'${_frequency.label} digest is ready.'` |
| `lib/features/conversation/presentation/add_people_sheet.dart:65` | done | `'Invitation sent.'` | (unchanged) |
| `lib/features/conversation/presentation/add_people_sheet.dart:71` | problem | `'Could not invite — try again.'` | `'The invitation was not sent. Try again.'` |
| `lib/features/conversation/presentation/conversation_row_actions.dart:53` | problem | `failure` | (unchanged) |
| `lib/features/conversation/presentation/conversation_screen.dart:540` | info | `'There is nowhere to forward this yet.'` | (unchanged) |
| `lib/features/conversation/presentation/conversation_screen.dart:631` | problem | `'Translation is not available right now.'` | (unchanged) |
| `lib/features/conversation/presentation/conversation_screen.dart:682` | problem | `AttachmentLifecycle.rejectionMessage(rejection)` | (unchanged) |
| `lib/features/conversation/presentation/conversation_screen.dart:733` | problem | `'Attachment failed — remove it and try again.'` | `'The attachment was not uploaded. Remove it and try again.'` |
| `lib/features/conversation/presentation/conversation_screen.dart:764` | info | `message` | (unchanged) |
| `lib/features/conversation/presentation/conversation_screen.dart:894` | problem | `'Could not send — try again.'` | `'Your message was not sent. Try again.'` |
| `lib/features/conversation/presentation/conversation_screen.dart:1052` | problem | `'The voice note could not be sent. ${AppErrorMapper.from(e).message}'` | `'Your voice note was not sent. Try again.'` |
| `lib/features/conversation/presentation/conversation_screen.dart:1065` | problem | `'Microphone permission is needed for voice notes.'` | `'Voice notes need the microphone. Allow it in your device settings.'` |
| `lib/features/conversation/presentation/conversation_screen.dart:1085` | problem | `'Recording could not start. ${AppErrorMapper.from(e).message}'` | `'Recording did not start. Try again.'` |
| `lib/features/conversation/presentation/conversation_screen.dart:1138` | problem | `'Could not send — try again.'` | `'Your message was not sent. Try again.'` |
| `lib/features/conversation/presentation/conversation_screen.dart:1234` | problem | `'Could not start the call — try again.'` | `'The call did not start. Try again.'` |
| `lib/features/conversation/presentation/conversation_screen.dart:2045` | problem | `'Could not decline this call. If you started it, ' 'end it from the call instead.'` | (unchanged) |
| `lib/features/conversation/presentation/message_interactions.dart:70` | problem | `failure` | (unchanged) |
| `lib/features/conversation/presentation/message_interactions.dart:173` | done | `text` | (unchanged) |
| `lib/features/conversation/presentation/message_interactions.dart:176` | problem | `'That could not be forwarded.'` | `'That message was not forwarded. Try again.'` |
| `lib/features/conversation/presentation/new_conversation_picker.dart:98` | problem | `'Could not start this conversation.'` | `'The conversation did not start. Try again.'` |
| `lib/features/devices/presentation/devices_screen.dart:55` | problem | `'Could not update that device. $e'` | `'That device was not updated. Try again.'` |
| `lib/features/devices/presentation/devices_screen.dart:100` | problem | `'Could not remove that device. $e'` | `'That device was not removed. Try again.'` |
| `lib/features/discover/widgets/discover_domain_cards.dart:98` | problem | `'That did not go through — try again.'` | `'That did not go through. Try again.'` |
| `lib/features/discover/widgets/discover_domain_cards.dart:259` | problem | `'That did not go through — try again.'` | `'That did not go through. Try again.'` |
| `lib/features/discover/widgets/person_suggestion_card.dart:78` | problem | `'Could not send that request — try again.'` | `'Your request was not sent. Try again.'` |
| `lib/features/feed/presentation/feed_interaction_bar.dart:139` | problem | `'Only institution speakers can react as institution.'` | `'Only people who speak for the institution can react as it.'` |
| `lib/features/feed/presentation/feed_interaction_bar.dart:147` | problem | `'Could not update like'` | `'Your like was not saved. Try again.'` |
| `lib/features/feed/presentation/feed_interaction_bar.dart:294` | done | `'Reposted'` | `'Reposted.'` |
| `lib/features/feed/presentation/feed_interaction_bar.dart:300` | problem | `'Could not repost: $message'` | `'That was not reposted. Try again.'` |
| `lib/features/feed/presentation/unified_feed_card.dart:1781` | problem | `'Could not update like'` | `'Your like was not saved. Try again.'` |
| `lib/features/feedback/presentation/feedback_screen.dart:67` | problem | `err.message` | (unchanged) |
| `lib/features/institutions/announcements/institution_announcement_composer.dart:336` | problem | `refusals.join(String.fromCharCode(10))` | (unchanged) |
| `lib/features/institutions/announcements/institution_announcement_composer.dart:661` | done | `'Scheduled. ${publishesLabel(at)}.'` | (unchanged) |
| `lib/features/institutions/announcements/institution_announcement_composer.dart:724` | done | `'$headline · $reach'` | (unchanged) |
| `lib/features/institutions/participation/participation_screen.dart:142` | problem | `'Could not update status: $e'` | `'The status was not updated. Try again.'` |
| `lib/features/institutions/posts/institution_post_composer_screen.dart:919` | info | `message` | (unchanged) |
| `lib/features/institutions/posts/institution_post_composer_screen.dart:1101` | done | `'Submitted for review'` | `'Submitted for review.'` |
| `lib/features/institutions/posts/institution_post_composer_screen.dart:1243` | done | `'Scheduled. ${publishesLabel(at)}.'` | (unchanged) |
| `lib/features/institutions/posts/institution_post_composer_screen.dart:1411` | done | `'$headline · $reach'` | (unchanged) |
| `lib/features/institutions/posts/institution_post_owner_actions.dart:83` | done | `'Post removed'` | `'Post removed.'` |
| `lib/features/institutions/posts/institution_post_owner_actions.dart:94` | problem | `AppErrorMapper.from(e, feature: 'delete this post').message` | (unchanged) |
| `lib/features/institutions/profile/institution_profile_screen.dart:498` | done | `'Public link copied'` | `'Public link copied.'` |
| `lib/features/institutions/profile/institution_profile_screen.dart:692` | done | `'${entry.label} link copied'` | `'${entry.label} link copied.'` |
| `lib/features/institutions/scheduling/scheduled_publication.dart:49` | problem | `problem` | (unchanged) |
| `lib/features/invitations/presentation/invitations_screen.dart:341` | problem | `'$e'` | `'The invitation was not accepted. Try again.'` |
| `lib/features/invitations/presentation/invitations_screen.dart:355` | problem | `'$e'` | `'The invitation was not declined. Try again.'` |
| `lib/features/invitations/presentation/invitations_screen.dart:445` | done | `'Invite link copied.'` | (unchanged) |
| `lib/features/invitations/presentation/invitations_screen.dart:466` | problem | `'$e'` | `'The invitation was not withdrawn. Try again.'` |
| `lib/features/invitations/presentation/invite_accept_screen.dart:214` | problem | `msg.isNotEmpty ? msg : 'Something went wrong.'` | `msg.isNotEmpty ? msg : 'The invitation was not accepted. Try again.'` |
| `lib/features/invitations/presentation/invite_accept_screen.dart:219` | problem | `'$e'` | `'The invitation was not accepted. Try again.'` |
| `lib/features/invitations/presentation/invite_create_screen.dart:279` | done | `link.isNotEmpty && !_collapsedMemberFlow ? '$destinationMessage Link created.' : destinationMessage` | (unchanged) |
| `lib/features/me/presentation/blocked_people_screen.dart:104` | done | `'Unblocked ${person.displayName}'` | `'${person.displayName} is unblocked.'` |
| `lib/features/me/presentation/blocked_people_screen.dart:109` | problem | `AppErrorMapper.from(e, feature: 'unblock this person').message` | (unchanged) |
| `lib/features/me/presentation/change_password_screen.dart:49` | done | `'Password changed successfully.'` | `'Password changed.'` |
| `lib/features/me/presentation/edit_profile_screen.dart:520` | done | `'Profile updated'` | `'Profile updated.'` |
| `lib/features/me/presentation/me_screen.dart:304` | info | `'LinkedIn authorization opened. Return here after approval.'` | `'LinkedIn is open. Approve there, then come back to Aura.'` |
| `lib/features/me/presentation/me_screen.dart:313` | problem | `'Could not start LinkedIn connection: $e'` | `'LinkedIn did not open. Try again.'` |
| `lib/features/me/presentation/me_screen.dart:355` | done | `'LinkedIn disconnected.'` | (unchanged) |
| `lib/features/me/presentation/me_screen.dart:358` | problem | `_readApiError(e, fallback: 'Could not disconnect LinkedIn.')` | (unchanged) |
| `lib/features/me/presentation/me_screen.dart:367` | problem | `'Could not disconnect LinkedIn: $e'` | `'LinkedIn was not disconnected. Try again.'` |
| `lib/features/me/presentation/me_screen.dart:461` | info | `'TikTok authorization opened. Return here after approval.'` | `'TikTok is open. Approve there, then come back to Aura.'` |
| `lib/features/me/presentation/me_screen.dart:470` | problem | `'Could not start TikTok connection: $e'` | `'TikTok did not open. Try again.'` |
| `lib/features/me/presentation/me_screen.dart:489` | done | `'TikTok connection refreshed.'` | (unchanged) |
| `lib/features/me/presentation/me_screen.dart:494` | problem | `_readApiError(e, fallback: 'Could not refresh TikTok connection.')` | (unchanged) |
| `lib/features/me/presentation/me_screen.dart:503` | problem | `'Could not refresh TikTok connection: $e'` | `'The TikTok connection was not refreshed. Try again.'` |
| `lib/features/me/presentation/me_screen.dart:545` | done | `'TikTok disconnected.'` | (unchanged) |
| `lib/features/me/presentation/me_screen.dart:548` | problem | `_readApiError(e, fallback: 'Could not disconnect TikTok.')` | (unchanged) |
| `lib/features/me/presentation/me_screen.dart:557` | problem | `'Could not disconnect TikTok: $e'` | `'TikTok was not disconnected. Try again.'` |
| `lib/features/me/presentation/notification_permission_tile.dart:146` | done | `'Browser notifications enabled'` | `'Browser notifications are on.'` |
| `lib/features/me/presentation/search_listing_screen.dart:51` | done | `listed ? 'Your profile will be included in Aura\'s sitemap.' : 'Your profile is no longer included in Aura\'s sitemap.'` | (unchanged) |
| `lib/features/me/presentation/search_listing_screen.dart:62` | problem | `AppErrorMapper.from(e, feature: 'change this setting').message` | (unchanged) |
| `lib/features/me/presentation/security_screen.dart:60` | problem | `e.toString().replaceFirst('Exception: ', '')` | `'That session was not signed out. Try again.'` |
| `lib/features/me/presentation/security_screen.dart:73` | problem | `e.toString().replaceFirst('Exception: ', '')` | `'Your other sessions were not signed out. Try again.'` |
| `lib/features/me/presentation/security_screen.dart:88` | problem | `e.toString().replaceFirst('Exception: ', '')` | `'That device was not removed. Try again.'` |
| `lib/features/me/presentation/security_screen.dart:130` | problem | `e.toString().replaceFirst('Exception: ', '')` | `'That device was not renamed. Try again.'` |
| `lib/features/meetings/presentation/booking_confirm_screen.dart:434` | done | `'Meeting link copied'` | `'Meeting link copied.'` |
| `lib/features/meetings/presentation/guest_waiting_room_screen.dart:126` | done | `'Meeting link copied'` | `'Meeting link copied.'` |
| `lib/features/meetings/presentation/institution_availability_screen.dart:171` | done | `'Link copied'` | `'Link copied.'` |
| `lib/features/meetings/presentation/institution_availability_screen.dart:302` | done | `'Link copied'` | `'Link copied.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:285` | problem | `'Unable to start meeting. Try again.'` | `'The meeting did not start. Try again.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:429` | problem | `'Please pick a date and time'` | `'Pick a date and time first.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:458` | done | `'Meeting updated'` | `'Meeting updated.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:463` | problem | `'Unable to update meeting. Try again.'` | `'The meeting was not updated. Try again.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:549` | problem | `'Unable to cancel meeting. Try again.'` | `'The meeting was not cancelled. Try again.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:561` | done | `'Meeting link copied'` | `'Meeting link copied.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:653` | done | `'Invitation sent to $email'` | `'Invitation sent to $email.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:658` | problem | `'Unable to send the invitation. Try again.'` | `'The invitation was not sent. Try again.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:676` | done | `'Calendar link copied'` | `'Calendar link copied.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:1344` | done | `'Agenda saved'` | `'Agenda saved.'` |
| `lib/features/meetings/presentation/meeting_detail_screen.dart:1349` | problem | `'Unable to save the agenda. Try again.'` | `'The agenda was not saved. Try again.'` |
| `lib/features/meetings/presentation/meeting_live_room_screen.dart:997` | problem | `'Unable to end meeting. Try again or leave the room.'` | `'The meeting did not end. Try again, or leave the room.'` |
| `lib/features/meetings/presentation/meeting_live_room_screen.dart:1018` | problem | `screenShareUnavailableReason()` | (unchanged) |
| `lib/features/meetings/presentation/meeting_live_room_screen.dart:3020` | problem | `'Could not open this item.'` | `'This item did not open. Try again.'` |
| `lib/features/meetings/presentation/meetings_home_screen.dart:632` | done | `'Booking link copied'` | `'Booking link copied.'` |
| `lib/features/meetings/presentation/pre_join_screen.dart:200` | info | `'Meeting is not yet live. Check back later.'` | `'This meeting is not live yet. Check back later.'` |
| `lib/features/meetings/presentation/widgets/meeting_assets_section.dart:75` | problem | `'Could not open this item.'` | `'This item did not open. Try again.'` |
| `lib/features/meetings/presentation/widgets/meeting_assets_section.dart:138` | problem | `'Could not add the link.'` | `'The link was not added. Try again.'` |
| `lib/features/meetings/presentation/widgets/meeting_assets_section.dart:161` | done | `'${file.name} attached to the meeting'` | `'${file.name} is attached to the meeting.'` |
| `lib/features/meetings/presentation/widgets/meeting_assets_section.dart:165` | problem | `'Upload failed. Try again.'` | `'The file was not uploaded. Try again.'` |
| `lib/features/meetings/presentation/widgets/meeting_workroom.dart:253` | done | `'Summary and outcomes saved'` | `'Summary and outcomes saved.'` |
| `lib/features/meetings/presentation/widgets/meeting_workroom.dart:257` | problem | `'Unable to save. Try again.'` | `'The summary was not saved. Try again.'` |
| `lib/features/meetings/presentation/widgets/meeting_workroom.dart:295` | done | `result.recipients > 0 ? 'Summary shared with ${result.recipients} participant${result.recipients == 1 ? '' : 's'}' : 'Summary shared'` | `result.recipients > 0 ? 'Summary shared with ${result.recipients} participant${result.recipients == 1 ? '' : 's'}.' : 'Summary shared.'` |
| `lib/features/meetings/presentation/widgets/meeting_workroom.dart:305` | info | `'Save the summary first, then share it.'` | (unchanged) |
| `lib/features/meetings/presentation/widgets/meeting_workroom.dart:335` | done | `'Promoted to ${type.label}'` | `'Promoted to ${type.label}.'` |
| `lib/features/meetings/presentation/widgets/meeting_workroom.dart:340` | problem | `'Could not promote message'` | `'The message was not promoted. Try again.'` |
| `lib/features/monetization/presentation/institution_billing_screen.dart:348` | problem | `_friendly(e)` | (unchanged) |
| `lib/features/monetization/presentation/institution_billing_screen.dart:366` | problem | `_friendly(e)` | (unchanged) |
| `lib/features/monetization/presentation/institution_billing_screen.dart:381` | problem | `_friendly(e)` | (unchanged) |
| `lib/features/monetization/presentation/institution_billing_screen.dart:388` | problem | `'The payment page could not be opened. Try again.'` | (unchanged) |
| `lib/features/posts/presentation/compose_screen.dart:1434` | problem | `'Could not load post for editing: $message'` | `'This post did not open for editing. Try again.'` |
| `lib/features/posts/presentation/compose_screen.dart:1495` | problem | `'Camera capture is not available here. Choose a file instead.'` | (unchanged) |
| `lib/features/posts/presentation/compose_screen.dart:1525` | problem | `'Video recording is not available here. Choose a file instead.'` | (unchanged) |
| `lib/features/posts/presentation/compose_screen.dart:1566` | problem | `resolution.rejectionMessage!` | (unchanged) |
| `lib/features/posts/presentation/compose_screen.dart:1571` | problem | `expect == AttachmentKind.video ? 'That is not a video file.' : 'That is not an image file.'` | (unchanged) |
| `lib/features/posts/presentation/compose_screen.dart:1594` | problem | `'Maximum $_maxAttachments attachments per post.'` | `'A post can have up to $_maxAttachments attachments.'` |
| `lib/features/posts/presentation/compose_screen.dart:1638` | problem | `'Could not upload attachment: $message'` | `'The attachment was not uploaded. Try again.'` |
| `lib/features/posts/presentation/compose_screen.dart:1898` | problem | `'Text is required.'` | `'Write something first.'` |
| `lib/features/posts/presentation/compose_screen.dart:2931` | problem | `'Text is required.'` | `'Write something first.'` |
| `lib/features/posts/presentation/compose_screen.dart:2936` | problem | `'Too long. Please shorten your post.'` | `'Your post is too long. Shorten it and try again.'` |
| `lib/features/posts/presentation/compose_screen.dart:2948` | problem | `kObjectionableContentMessage` | (unchanged) |
| `lib/features/posts/presentation/compose_screen.dart:2955` | problem | `'Select a topic before publishing.'` | `'Choose a topic first.'` |
| `lib/features/posts/presentation/compose_screen.dart:2965` | info | `'Please wait for attachments to finish uploading.'` | `'Wait for the attachments to finish uploading.'` |
| `lib/features/posts/presentation/compose_screen.dart:2984` | problem | `'TikTok publishing requires one uploaded video.'` | `'TikTok takes one uploaded video.'` |
| `lib/features/posts/presentation/compose_screen.dart:3019` | problem | `'Review the Governance panel before publishing.'` | (unchanged) |
| `lib/features/posts/presentation/compose_screen.dart:3152` | done | `_isReply ? 'Your reply is live in the discussion.' : 'Your discussion is live.'` | (unchanged) |
| `lib/features/posts/presentation/compose_screen.dart:3870` | problem | `cap.state == DestinationState.reconnectRequired ? '${cap.label} needs signing in again — open Me › Connected accounts.' : 'Connect ${cap.label} from Me › Connected accounts.'` | (unchanged) |
| `lib/features/posts/presentation/widgets/post_card/post_owner_actions.dart:84` | done | `'Work deleted'` | `'Work deleted.'` |
| `lib/features/posts/presentation/widgets/post_card/post_owner_actions.dart:97` | problem | `'Could not delete post'` | `'The work was not deleted. Try again.'` |
| `lib/features/posts/presentation/widgets/post_card.dart:486` | done | `'Author blocked. A moderator will review within 24 hours.'` | (unchanged) |
| `lib/features/posts/presentation/widgets/post_card.dart:495` | problem | `'Could not complete the block. Please try again.'` | `'The block did not go through. Try again.'` |
| `lib/features/posts/presentation/widgets/post_card.dart:1324` | done | `'Work reposted'` | `'Work reposted.'` |
| `lib/features/public/presentation/thread_screen.dart:369` | done | `'Link copied to clipboard.'` | `'Link copied.'` |
| `lib/features/public/widgets/reply_unit.dart:383` | done | `'Author blocked. A moderator will review within 24 hours.'` | (unchanged) |
| `lib/features/public/widgets/reply_unit.dart:392` | problem | `'Could not block. Try again later.'` | `'This person was not blocked. Try again.'` |
| `lib/features/realtime/presentation/realtime_room_screen.dart:890` | problem | `'Could not go live — try again.'` | `'You did not go live. Try again.'` |
| `lib/features/realtime/presentation/realtime_room_screen.dart:913` | problem | `'Could not end the live — try again.'` | `'The live did not end. Try again.'` |
| `lib/features/realtime/presentation/realtime_room_screen.dart:945` | problem | `screenShareUnavailableReason()` | (unchanged) |
| `lib/features/realtime/presentation/realtime_room_screen.dart:2160` | info | `'You joined a live ${meta.type.label}'` | `'You joined a live ${meta.type.label}.'` |
| `lib/features/topics/aura_topic_selector.dart:123` | info | `droppedCount == 1 ? 'Removed 1 secondary topic that no longer relates to the new primary topic.' : 'Removed $droppedCount secondary topics that no longer relate to the new primary topic.'` | (unchanged) |
| `lib/features/topics/aura_topic_selector.dart:176` | problem | `'Could not get topic suggestions. Try again.'` | `'Topic suggestions did not load. Try again.'` |
| `lib/screens/white_paper_screen.dart:92` | problem | `'Could not open the PDF.'` | `'The PDF did not open. Try again.'` |
| `lib/shared/media/profile_media_editor.dart:448` | problem | `'Could not save image: $e'` | `'The image was not saved. Try again.'` |
