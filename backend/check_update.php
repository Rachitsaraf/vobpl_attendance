<?php
// Set CORS and JSON Headers for Flutter API Call
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Company App Release Configuration (v1.6.1 Build 22)
$response = [
    "latest_version" => "1.6.1",
    "version_code" => 22,
    "apk_url" => "https://api.vobplsmart.in/api/attendance/latest.apk",
    "force_update" => true,
    "release_notes" => "1. Fixed Check-Out time visibility on Dashboard\n2. Uniform Check-In & Check-Out timing across Dashboard and History\n3. Support for multiple shifts/punches on the same day\n4. Flexible GPS & Dynamic Geofencing for Field Workers\n5. On-Duty Route Breadcrumbs Tracking & Distance Calculation\n6. Field Visit Purpose & Check-Out Remarks Modal\n7. Bug fixes & Performance Optimizations"
];

http_response_code(200);
echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
?>
