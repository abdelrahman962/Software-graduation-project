# Quick Test Script
# Run this to quickly verify the new lab owner registration feature

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Medical Lab System - Quick Test Guide" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Step 1: Start Backend Server" -ForegroundColor Yellow
Write-Host "In a new terminal, run:" -ForegroundColor White
Write-Host "  cd backend" -ForegroundColor Gray
Write-Host "  npm run dev" -ForegroundColor Gray
Write-Host ""

Write-Host "Step 2: Start Frontend" -ForegroundColor Yellow
Write-Host "In another terminal, run:" -ForegroundColor White
Write-Host "  cd frontend_flutter" -ForegroundColor Gray
Write-Host "  flutter run -d chrome" -ForegroundColor Gray
Write-Host ""

Write-Host "Step 3: Test New Features" -ForegroundColor Yellow
Write-Host ""

Write-Host "✨ Lab Owner Registration:" -ForegroundColor Green
Write-Host "  1. Go to http://localhost:your-port/contact" -ForegroundColor White
Write-Host "  2. Click 'Register Now' button" -ForegroundColor White
Write-Host "  3. Fill all 4 steps" -ForegroundColor White
Write-Host "  4. Test password strength meter (type different passwords)" -ForegroundColor White
Write-Host "  5. Test email validation (try invalid emails)" -ForegroundColor White
Write-Host "  6. Must check 'Terms of Service' to submit" -ForegroundColor White
Write-Host "  7. Submit and verify success dialog" -ForegroundColor White
Write-Host ""

Write-Host "✨ Admin Approval:" -ForegroundColor Green
Write-Host "  1. Login as admin" -ForegroundColor White
Write-Host "  2. Go to dashboard -> Pending Approvals" -ForegroundColor White
Write-Host "  3. Expand pending owner details" -ForegroundColor White
Write-Host "  4. Click Approve or Reject" -ForegroundColor White
Write-Host "  5. Verify emails sent" -ForegroundColor White
Write-Host ""

Write-Host "✨ Performance Tests:" -ForegroundColor Green
Write-Host "  1. Login as owner" -ForegroundColor White
Write-Host "  2. Navigate to Orders page" -ForegroundColor White
Write-Host "  3. Verify fast loading (<1 second)" -ForegroundColor White
Write-Host "  4. Navigate to Doctors page" -ForegroundColor White
Write-Host "  5. Verify all doctors shown (not filtered)" -ForegroundColor White
Write-Host ""

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "For detailed testing, see:" -ForegroundColor Yellow
Write-Host "  - TESTING_GUIDE.md" -ForegroundColor White
Write-Host "  - TESTING_CHECKLIST.md" -ForegroundColor White
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
