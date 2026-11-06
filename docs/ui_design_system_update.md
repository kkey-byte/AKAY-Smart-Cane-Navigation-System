# AKAY frontend visual update

Implemented the supplied blue-and-white references by extending the existing Gabay theme and widgets. No application architecture or state-management replacement was introduced.

The light palette uses background #F3F6FD, white cards, primary #2563EB, deep blue #173B82, text #172554, and secondary text #64748B. Shared typography uses regular/medium weights, with limited semibold headings. Shared dimensions define 20px screen padding, 16px card padding, 24px card radii, 18px control radii, and 48px minimum action heights. Existing specialized layouts retain their content and interactions.

Login and Sign Up share a responsive, keyboard-aware shell, icy-blue gradients, decorative circles, soft raised fields, and the existing unmodified AKAY artwork in a rounded square. Existing validation and submission handlers are unchanged. No social login or password-reset integration was added.

Shared cards use soft blue shadows and light highlights. Floating bottom navigation uses one clipped blur layer with a translucent surface; content cards stay opaque for readability. Primary actions use the shared blue gradient; secondary/Cancel actions use neutral surfaces; destructive connection actions retain confirmations with distinct red styling. Profiles, reports, health information, notifications, onboarding, and surrounding tracking panels inherit or reuse these styles. No map implementation was changed.

Frontend implementation files modified or added:

- [lib/pages/caregiver/linked_navigator_cane_page.dart](C:/Users/Asus/app_mobile/lib/pages/caregiver/linked_navigator_cane_page.dart)
- [lib/pages/landing_page.dart](C:/Users/Asus/app_mobile/lib/pages/landing_page.dart)
- [lib/pages/login_page.dart](C:/Users/Asus/app_mobile/lib/pages/login_page.dart)
- [lib/pages/shared/change_password_page.dart](C:/Users/Asus/app_mobile/lib/pages/shared/change_password_page.dart)
- [lib/pages/shared/edit_profile_page.dart](C:/Users/Asus/app_mobile/lib/pages/shared/edit_profile_page.dart)
- [lib/pages/shared/information_health_status_page.dart](C:/Users/Asus/app_mobile/lib/pages/shared/information_health_status_page.dart)
- [lib/pages/shared/pairing_management_page.dart](C:/Users/Asus/app_mobile/lib/pages/shared/pairing_management_page.dart)
- [lib/pages/signup_page.dart](C:/Users/Asus/app_mobile/lib/pages/signup_page.dart)
- [lib/pages/visually_impaired/vi_voice_assistant_page.dart](C:/Users/Asus/app_mobile/lib/pages/visually_impaired/vi_voice_assistant_page.dart)
- [lib/theme/gabay_theme.dart](C:/Users/Asus/app_mobile/lib/theme/gabay_theme.dart)
- [lib/widgets/auth/gabay_auth_scaffold.dart](C:/Users/Asus/app_mobile/lib/widgets/auth/gabay_auth_scaffold.dart)
- [lib/widgets/dashboard_widgets/bottom_nav.dart](C:/Users/Asus/app_mobile/lib/widgets/dashboard_widgets/bottom_nav.dart)
- [lib/widgets/dashboard_widgets/caregiver_reports_body.dart](C:/Users/Asus/app_mobile/lib/widgets/dashboard_widgets/caregiver_reports_body.dart)
- [lib/widgets/dashboard_widgets/dashboard_navigation_view.dart](C:/Users/Asus/app_mobile/lib/widgets/dashboard_widgets/dashboard_navigation_view.dart)
- [lib/widgets/dashboard_widgets/location_card.dart](C:/Users/Asus/app_mobile/lib/widgets/dashboard_widgets/location_card.dart)
- [lib/widgets/dashboard_widgets/recorded_reports.dart](C:/Users/Asus/app_mobile/lib/widgets/dashboard_widgets/recorded_reports.dart)
- [lib/widgets/dashboard_widgets/stat_card.dart](C:/Users/Asus/app_mobile/lib/widgets/dashboard_widgets/stat_card.dart)
- [lib/widgets/notifications/notification_card.dart](C:/Users/Asus/app_mobile/lib/widgets/notifications/notification_card.dart)
- [lib/widgets/notifications/notification_section_label.dart](C:/Users/Asus/app_mobile/lib/widgets/notifications/notification_section_label.dart)
- [lib/widgets/onboarding/onboarding_widgets.dart](C:/Users/Asus/app_mobile/lib/widgets/onboarding/onboarding_widgets.dart)
- [lib/widgets/profile/address_editor_sheet.dart](C:/Users/Asus/app_mobile/lib/widgets/profile/address_editor_sheet.dart)
- [lib/widgets/profile/logout_confirmation_dialog.dart](C:/Users/Asus/app_mobile/lib/widgets/profile/logout_confirmation_dialog.dart)
- [lib/widgets/profile/profile_header_clipper.dart](C:/Users/Asus/app_mobile/lib/widgets/profile/profile_header_clipper.dart)
- [lib/widgets/profile/profile_menu_widgets.dart](C:/Users/Asus/app_mobile/lib/widgets/profile/profile_menu_widgets.dart)
- [lib/widgets/shared/dashboard_pairing_card.dart](C:/Users/Asus/app_mobile/lib/widgets/shared/dashboard_pairing_card.dart)
- [lib/widgets/shared/gabay_blue_app_bar.dart](C:/Users/Asus/app_mobile/lib/widgets/shared/gabay_blue_app_bar.dart)
- [lib/widgets/shared/gabay_detail_page_scaffold.dart](C:/Users/Asus/app_mobile/lib/widgets/shared/gabay_detail_page_scaffold.dart)
- [lib/widgets/shared/gabay_glass_surface.dart](C:/Users/Asus/app_mobile/lib/widgets/shared/gabay_glass_surface.dart)
- [lib/widgets/track/eta_card.dart](C:/Users/Asus/app_mobile/lib/widgets/track/eta_card.dart)
- [lib/widgets/track/navigator_destination_panel.dart](C:/Users/Asus/app_mobile/lib/widgets/track/navigator_destination_panel.dart)
- [lib/widgets/track/navigator_monitor_sheet.dart](C:/Users/Asus/app_mobile/lib/widgets/track/navigator_monitor_sheet.dart)
- [lib/widgets/track/recent_place_tile.dart](C:/Users/Asus/app_mobile/lib/widgets/track/recent_place_tile.dart)
- [lib/widgets/track/route_search_card.dart](C:/Users/Asus/app_mobile/lib/widgets/track/route_search_card.dart)
- [lib/widgets/track/route_timeline_panel.dart](C:/Users/Asus/app_mobile/lib/widgets/track/route_timeline_panel.dart)
- [lib/widgets/track/saved_place_tile.dart](C:/Users/Asus/app_mobile/lib/widgets/track/saved_place_tile.dart)
- [lib/widgets/track/turn_by_turn_panel.dart](C:/Users/Asus/app_mobile/lib/widgets/track/turn_by_turn_panel.dart)

Verification/test files updated:

- [test/auth_design_test.dart](C:/Users/Asus/app_mobile/test/auth_design_test.dart)
- [test/action_button_theme_test.dart](C:/Users/Asus/app_mobile/test/action_button_theme_test.dart)
- [test/edit_profile_layout_test.dart](C:/Users/Asus/app_mobile/test/edit_profile_layout_test.dart)
- [test/dashboard_live_test.dart](C:/Users/Asus/app_mobile/test/dashboard_live_test.dart)

Verification results:

- Broad regression run: 120 passed, one existing stale report assertion failed in test/user_data_empty_states_test.dart. It expects the older “Unavailable” labels and trip-count text removed by earlier requested UI work. This update did not alter that report behavior or that test.
- The unrelated starter counter test (test/widget_test.dart) was excluded because it still expects the Flutter template counter app.
- Additional final focused checks: button styles/narrow enlarged-text navigation (3 passed), pairing/security/access states (7 passed), and authentication/profile checks (11 passed).
- Flutter analysis: no errors or warnings; three pre-existing informational notices remain in navigator_onboarding_page.dart, blob_painter.dart, and gabay_page_route.dart.
- Flutter debug frontend bundle compilation succeeded. This is not an APK install or device-launch verification.
- Phone authentication layouts were tested at 390px and 320px widths, including enlarged text, dark mode, validation, password visibility, and keyboard insets.
- Content hashes match the initial snapshot for app_mobile_backend, lib/services, lib/models, lib/config, firebase_options.dart, the shared TrackPage, GabayTrackMap, and RoleRouter. Backend files, API configurations, database structures, Firebase integration, map implementations, and service code were not changed by this update.
- Login and Sign Up pre-build state/validation/submission code matches the committed source after whitespace normalization.
- Live authentication, real GPS, caregiver synchronization, SOS delivery, device/LiDAR behavior, launch on a phone, and physical-device performance were not verified. Their existing implementations were preserved.

Rendered authentication previews (synthetic, no account data):

- [Login](C:/Users/Asus/app_mobile/build/ui_preview/login.png)
- [Sign Up](C:/Users/Asus/app_mobile/build/ui_preview/signup.png)

