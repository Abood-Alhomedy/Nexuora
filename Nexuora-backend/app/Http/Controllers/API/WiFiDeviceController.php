<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\Process\Process;

class WiFiDeviceController extends Controller
{
    // مهلة الاتصال بالجهاز (ثانية)
    private const ADB_TIMEOUT   = 15;
    // مهلة تشغيل flutter run (ثانية)
    private const RUN_TIMEOUT   = 120;
    // منفذ ADB الافتراضي عبر Wi-Fi
    private const DEFAULT_PORT  = 5555;

    private function adb(): string
    {
        $winPath = 'C:\\Sdk\\platform-tools\\adb.exe';
        if (file_exists($winPath)) {
            return $winPath;
        }
        $envPath = env('ADB_PATH');
        if ($envPath && file_exists($envPath)) {
            return $envPath;
        }
        return 'adb';
    }

    // ─────────────────────────────────────────────────────────────
    // 1. اتصال ADB عبر Wi-Fi
    // ─────────────────────────────────────────────────────────────

    /**
     * POST /api/wifi-device/connect
     * body: { ip, port? }
     */
    public function connect(Request $request)
    {
        $request->validate([
            'ip'   => 'required|ip',
            'port' => 'nullable|integer|min:1024|max:65535',
        ]);

        $ip   = $request->ip;
        $port = $request->port ?? self::DEFAULT_PORT;
        $host = "{$ip}:{$port}";

        try {
            $proc = new Process([$this->adb(), 'connect', $host]);
            $proc->setTimeout(self::ADB_TIMEOUT);
            $proc->run();

            $out = trim($proc->getOutput());

            // adb يُرجع "connected to …" أو "already connected"
            $success = str_contains($out, 'connected to') || str_contains($out, 'already connected');

            if ($success) {
                return response()->json([
                    'status'   => true,
                    'message'  => "Connected to {$host}",
                    'data'     => ['deviceId' => $host, 'ip' => $ip, 'port' => $port],
                ]);
            }

            return response()->json([
                'status'  => false,
                'message' => $out ?: 'Failed to connect. Make sure Wi-Fi Debugging is enabled.',
            ], 422);

        } catch (\Exception $e) {
            Log::error("[WiFiDevice] connect: {$e->getMessage()}");
            return response()->json([
                'status'  => false,
                'message' => 'ADB error: ' . $e->getMessage(),
            ], 500);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 2. قطع الاتصال
    // ─────────────────────────────────────────────────────────────

    /**
     * POST /api/wifi-device/disconnect
     * body: { deviceId }
     */
    public function disconnect(Request $request)
    {
        $request->validate(['deviceId' => 'required|string']);

        try {
            $proc = new Process([$this->adb(), 'disconnect', $request->deviceId]);
            $proc->setTimeout(self::ADB_TIMEOUT);
            $proc->run();

            return response()->json([
                'status'  => true,
                'message' => 'Disconnected from ' . $request->deviceId,
            ]);
        } catch (\Exception $e) {
            Log::error("[WiFiDevice] disconnect: {$e->getMessage()}");
            return response()->json(['status' => false, 'message' => $e->getMessage()], 500);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 3. قائمة الأجهزة المتصلة
    // ─────────────────────────────────────────────────────────────

    /**
     * GET /api/wifi-device/devices
     */
    public function devices()
    {
        try {
            $proc = new Process([$this->adb(), 'devices', '-l']);
            $proc->setTimeout(self::ADB_TIMEOUT);
            $proc->run();

            if (!$proc->isSuccessful()) {
                return response()->json([
                    'status'  => false,
                    'message' => 'ADB check failed: ' . trim($proc->getErrorOutput() . ' ' . $proc->getOutput()) . ' (Path: ' . $this->adb() . ')',
                    'data'    => ['devices' => []],
                ]);
            }

            $devices = $this->parseDevices($proc->getOutput());

            return response()->json([
                'status'  => true,
                'message' => count($devices) . ' device(s) found',
                'data'    => ['devices' => $devices],
            ]);

        } catch (\Exception $e) {
            Log::error("[WiFiDevice] devices: {$e->getMessage()}");
            return response()->json(['status' => false, 'message' => $e->getMessage()], 500);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 3-B. الاكتشاف التلقائي عبر USB → Wi-Fi
    // ─────────────────────────────────────────────────────────────

    /**
     * GET /api/wifi-device/detect-usb
     *
     * خطوات العمل:
     *   1) adb devices         → نجد الأجهزة المتصلة بـ USB (serial)
     *   2) adb shell ip route  → نقرأ IP الـ Wi-Fi من الجهاز
     *   3) adb tcpip 5555      → نُفعّل وضع TCP/IP على الجهاز
     *   4) adb connect IP:5555 → نتصل لاسلكياً
     *   5) نُرجع قائمة الأجهزة التي تم اكتشافها
     */
    public function detectFromUsb()
    {
        try {
            // 1. جلب الأجهزة المتصلة حالياً
            $proc = new Process([$this->adb(), 'devices']);
            $proc->setTimeout(self::ADB_TIMEOUT);
            $proc->run();

            $usbSerials = $this->parseUsbSerials($proc->getOutput());

            if (empty($usbSerials)) {
                return response()->json([
                    'status'  => false,
                    'message' => 'No USB device found. Connect your device and enable USB Debugging.',
                    'data'    => ['devices' => []],
                ]);
            }

            $discovered = [];

            foreach ($usbSerials as $serial) {
                // 2. قراءة IP الـ Wi-Fi من الجهاز
                $ip = $this->getDeviceWifiIp($serial);

                if (!$ip) {
                    Log::warning("[WiFiDevice] Could not get IP for USB device: {$serial}");
                    continue;
                }

                // 3. تفعيل TCP/IP على المنفذ 5555
                $tcpip = new Process([$this->adb(), '-s', $serial, 'tcpip', '5555']);
                $tcpip->setTimeout(10);
                $tcpip->run();
                sleep(2); // انتظر ثانيتين حتى يستجيب الجهاز

                // 4. الاتصال لاسلكياً
                $host    = "{$ip}:5555";
                $connect = new Process([$this->adb(), 'connect', $host]);
                $connect->setTimeout(self::ADB_TIMEOUT);
                $connect->run();
                $out = trim($connect->getOutput());

                $success = str_contains($out, 'connected to') || str_contains($out, 'already connected');

                if ($success) {
                    $name = $this->getDeviceName($serial); // يقرأ model من USB قبل قطعه
                    $discovered[] = [
                        'id'          => $host,
                        'name'        => $name,
                        'ip'          => $ip,
                        'port'        => 5555,
                        'usbSerial'   => $serial,
                        'status'      => 'device',
                        'isWifi'      => true,
                        'isEmulator'  => false,
                        'autoDetected'=> true,
                    ];
                } else {
                    Log::warning("[WiFiDevice] connect failed for {$host}: {$out}");
                }
            }

            if (empty($discovered)) {
                return response()->json([
                    'status'  => false,
                    'message' => 'Device found via USB but Wi-Fi IP could not be detected. '
                               . 'Make sure Wi-Fi is ON and device is on the same network as the server.',
                    'data'    => ['devices' => []],
                ]);
            }

            return response()->json([
                'status'  => true,
                'message' => count($discovered) . ' device(s) auto-detected via USB',
                'data'    => ['devices' => $discovered],
            ]);

        } catch (\Exception $e) {
            Log::error("[WiFiDevice] detectFromUsb: {$e->getMessage()}");
            return response()->json([
                'status'  => false,
                'message' => 'Error: ' . $e->getMessage(),
            ], 500);
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 4. تشغيل المشروع على جهاز Wi-Fi
    // ─────────────────────────────────────────────────────────────


    /**
     * POST /api/wifi-device/run
     * body: { projectId, projectName, deviceId, screens[] }
     */
    public function run(Request $request)
    {
        $request->validate([
            'projectId'   => 'required|integer',
            'projectName' => 'required|string|max:100',
            'deviceId'    => 'required|string',          // مثال: 192.168.1.50:5555
            'screens'     => 'nullable|array',
        ]);

        $projectId   = $request->projectId;
        $projectName = preg_replace('/[^a-z0-9_]/', '_', strtolower($request->projectName));
        $deviceId    = $request->deviceId;
        $screens     = $request->screens ?? [];

        // التأكد من وجود الجهاز
        if (!$this->deviceIsConnected($deviceId)) {
            return response()->json([
                'status'  => false,
                'message' => "Device {$deviceId} is not connected via ADB. Please connect first.",
            ], 422);
        }

        // مجلد مؤقت للمشروع
        $tempDir = storage_path("app/temp/wifi_project_{$projectId}");
        $this->ensureDir($tempDir);

        // توليد ملفات المشروع
        $this->generateProject($tempDir, $projectName, $screens);

        // تشغيل المشروع
        $result = $this->launchFlutter($tempDir, $deviceId, $projectId);

        if ($result['success']) {
            return response()->json([
                'status'  => true,
                'message' => "Running on {$deviceId}",
                'data'    => [
                    'pid'      => $result['pid'],
                    'deviceId' => $deviceId,
                    'logFile'  => $result['logFile'],
                ],
            ]);
        }

        return response()->json([
            'status'  => false,
            'message' => $result['message'],
        ], 500);
    }

    // ─────────────────────────────────────────────────────────────
    // 5. Hot Reload
    // ─────────────────────────────────────────────────────────────

    /**
     * POST /api/wifi-device/hot-reload
     * body: { projectId, screens[] }
     */
    public function hotReload(Request $request)
    {
        $request->validate([
            'projectId' => 'required|integer',
            'screens'   => 'nullable|array',
        ]);

        $projectId = $request->projectId;
        $tempDir   = storage_path("app/temp/wifi_project_{$projectId}");

        if (!file_exists($tempDir)) {
            return response()->json(['status' => false, 'message' => 'Project not running.'], 404);
        }

        // تحديث ملفات الشاشات فقط
        if (!empty($request->screens)) {
            $libPath = "{$tempDir}/lib";
            foreach ($request->screens as $screen) {
                $name    = $this->safeName($screen['name'] ?? 'Screen');
                $content = $this->buildScreenFile($name, $screen['data'] ?? []);
                file_put_contents("{$libPath}/{$name}.dart", $content);
            }
        }

        // إرسال إشارة 'r' للـ flutter run عبر ملف FIFO أو PID
        $pidFile = storage_path("app/temp/pid_{$projectId}.txt");
        if (file_exists($pidFile)) {
            $pid = (int) file_get_contents($pidFile);
            if ($pid > 0) {
                // إرسال SIGUSR1 → flutter run يُجري Hot Reload
                posix_kill($pid, SIGUSR1);
                return response()->json(['status' => true, 'message' => 'Hot reload triggered.']);
            }
        }

        return response()->json(['status' => false, 'message' => 'No running process found.'], 404);
    }

    // ─────────────────────────────────────────────────────────────
    // 6. إيقاف التشغيل
    // ─────────────────────────────────────────────────────────────

    /**
     * POST /api/wifi-device/stop
     * body: { projectId }
     */
    public function stop(Request $request)
    {
        $request->validate(['projectId' => 'required|integer']);

        $projectId = $request->projectId;
        $pidFile   = storage_path("app/temp/pid_{$projectId}.txt");

        if (file_exists($pidFile)) {
            $pid = (int) file_get_contents($pidFile);
            if ($pid > 0) {
                posix_kill($pid, SIGTERM);
                sleep(1);
                posix_kill($pid, SIGKILL); // تأكيد الإيقاف
            }
            unlink($pidFile);
        }

        // حذف المجلد المؤقت
        $tempDir = storage_path("app/temp/wifi_project_{$projectId}");
        if (file_exists($tempDir)) {
            $this->deleteDir($tempDir);
        }

        return response()->json(['status' => true, 'message' => 'Project stopped.']);
    }

    // ─────────────────────────────────────────────────────────────
    // دوال مساعدة خاصة
    // ─────────────────────────────────────────────────────────────

    private function parseDevices(string $output): array
    {
        $devices = [];
        foreach (explode("\n", $output) as $line) {
            $line = trim($line);
            if (empty($line) || str_starts_with($line, 'List of devices')) continue;

            // السطر: "192.168.1.50:5555  device product:..."
            if (preg_match('/^(\S+)\s+(device|offline|unauthorized)/', $line, $m)) {
                $id     = $m[1];
                $status = $m[2];
                $name   = $this->getDeviceName($id);
                $devices[] = [
                    'id'         => $id,
                    'name'       => $name,
                    'status'     => $status,
                    'isWifi'     => str_contains($id, ':'),
                    'isEmulator' => str_starts_with($id, 'emulator-'),
                ];
            }
        }
        return $devices;
    }

    private function getDeviceName(string $deviceId): string
    {
        try {
            $proc = new Process([$this->adb(), '-s', $deviceId, 'shell', 'getprop', 'ro.product.model']);
            $proc->setTimeout(5);
            $proc->run();
            $name = trim($proc->getOutput());
            return $name ?: $deviceId;
        } catch (\Throwable $e) {
            return $deviceId;
        }
    }

    private function deviceIsConnected(string $deviceId): bool
    {
        $proc = new Process([$this->adb(), 'devices']);
        $proc->setTimeout(self::ADB_TIMEOUT);
        $proc->run();
        return str_contains($proc->getOutput(), $deviceId);
    }

    private function launchFlutter(string $dir, string $deviceId, int $projectId): array
    {
        try {
            // تأكد من وجود Flutter
            $which = new Process(['which', 'flutter']);
            $which->run();
            if (!$which->isSuccessful()) {
                return ['success' => false, 'message' => 'Flutter SDK not found on server.'];
            }

            // flutter pub get
            $pubGet = new Process(['flutter', 'pub', 'get'], $dir);
            $pubGet->setTimeout(60);
            $pubGet->run();
            if (!$pubGet->isSuccessful()) {
                return ['success' => false, 'message' => 'pub get failed: ' . $pubGet->getErrorOutput()];
            }

            // ملف log
            $logFile = storage_path("app/temp/flutter_{$projectId}.log");

            // بناء الأمر
            $cmd = ['flutter', 'run', '--device-id', $deviceId, '--no-sound-null-safety'];

            // تشغيل في الخلفية عبر nohup
            $bgCmd = 'nohup ' . implode(' ', array_map('escapeshellarg', $cmd))
                   . " > {$logFile} 2>&1 & echo $!";

            $pid = (int) trim(shell_exec("cd " . escapeshellarg($dir) . " && {$bgCmd}"));

            if ($pid > 0) {
                // حفظ PID لاحقاً (hot reload / stop)
                file_put_contents(storage_path("app/temp/pid_{$projectId}.txt"), $pid);
                // انتظار ظهور نص التشغيل في Log
                $this->waitForReady($logFile);
                return ['success' => true, 'pid' => $pid, 'logFile' => $logFile];
            }

            return ['success' => false, 'message' => 'Failed to start flutter process.'];

        } catch (\Exception $e) {
            return ['success' => false, 'message' => $e->getMessage()];
        }
    }

    private function waitForReady(string $logFile, int $maxSeconds = 90): void
    {
        $start = time();
        while (time() - $start < $maxSeconds) {
            if (file_exists($logFile)) {
                $log = file_get_contents($logFile);
                if (str_contains($log, 'Flutter run key commands') ||
                    str_contains($log, 'To hot restart') ||
                    str_contains($log, 'Syncing files to device')) {
                    return;
                }
            }
            usleep(500_000); // 0.5s
        }
    }

    private function generateProject(string $dir, string $name, array $screens): void
    {
        $this->ensureDir("{$dir}/lib");

        // pubspec.yaml
        file_put_contents("{$dir}/pubspec.yaml", $this->buildPubspec($name));

        // الشاشات
        $screenImports = '';
        $firstScreen   = '';
        foreach ($screens as $i => $screen) {
            $sName          = $this->safeName($screen['name'] ?? "Screen{$i}");
            $screenImports .= "import '{$sName}.dart';\n";
            if ($i === 0) $firstScreen = $sName;
            file_put_contents("{$dir}/lib/{$sName}.dart", $this->buildScreenFile($sName, $screen['data'] ?? []));
        }

        // main.dart
        file_put_contents("{$dir}/lib/main.dart", $this->buildMainDart($name, $screenImports, $firstScreen));
    }

    private function buildPubspec(string $name): string
    {
        return <<<YAML
name: {$name}
description: "Generated by Nexuora"
version: 1.0.0+1

environment:
  sdk: ">=3.0.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
YAML;
    }

    private function buildMainDart(string $appName, string $imports, string $home): string
    {
        $homeWidget = $home ? "{$home}()" : 'const _PlaceholderScreen()';
        return <<<DART
import 'package:flutter/material.dart';
{$imports}
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '{$appName}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: {$homeWidget},
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('{$appName}')),
        body: const Center(child: Text('No screens yet')),
      );
}
DART;
    }

    private function buildScreenFile(string $name, array $data): string
    {
        $title = str_replace('_', ' ', $name);
        return <<<DART
import 'package:flutter/material.dart';

class {$name} extends StatefulWidget {
  const {$name}({super.key});
  @override
  State<{$name}> createState() => _{$name}State();
}

class _{$name}State extends State<{$name}> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('{$title}')),
      body: const Center(child: Text('{$title}')),
    );
  }
}
DART;
    }

    private function safeName(string $raw): string
    {
        $name = preg_replace('/[^a-zA-Z0-9]/', '_', $raw);
        return ucfirst($name);
    }

    private function ensureDir(string $path): void
    {
        if (!file_exists($path)) {
            mkdir($path, 0777, true);
        }
    }

    private function deleteDir(string $dir): void
    {
        foreach (array_diff(scandir($dir), ['.', '..']) as $f) {
            $p = "{$dir}/{$f}";
            is_dir($p) ? $this->deleteDir($p) : unlink($p);
        }
        rmdir($dir);
    }

    // ─────────────────────────────────────────────────────────────
    // دوال مساعدة للاكتشاف التلقائي
    // ─────────────────────────────────────────────────────────────

    /**
     * يُرجع قائمة بـ serial numbers الأجهزة المتصلة عبر USB فقط
     * (يستبعد الأجهزة المتصلة بـ Wi-Fi التي تحتوي على ":" في معرّفها)
     */
    private function parseUsbSerials(string $adbOutput): array
    {
        $serials = [];
        foreach (explode("\n", $adbOutput) as $line) {
            $line = trim($line);
            if (empty($line) || str_starts_with($line, 'List of devices')) continue;

            if (preg_match('/^(\S+)\s+device/', $line, $m)) {
                $id = $m[1];
                // أجهزة Wi-Fi تحتوي ":" مثل 192.168.1.5:5555 — نتخطاها
                if (!str_contains($id, ':')) {
                    $serials[] = $id;
                }
            }
        }
        return $serials;
    }

    /**
     * يقرأ عنوان IP لشبكة Wi-Fi من الجهاز عبر USB
     * يجرب عدة طرق: ip route → ip addr → ifconfig
     */
    private function getDeviceWifiIp(string $serial): ?string
    {
        $adb = $this->adb();
        $cmds = [
            // الطريقة 1: ip route (Android 6+)
            [$adb, '-s', $serial, 'shell', 'ip', 'route', 'show', 'dev', 'wlan0'],
            // الطريقة 2: ip addr
            [$adb, '-s', $serial, 'shell', 'ip', 'addr', 'show', 'wlan0'],
            // الطريقة 3: ifconfig (Android قديم)
            [$adb, '-s', $serial, 'shell', 'ifconfig', 'wlan0'],
            // الطريقة 4: getprop (بعض الأجهزة)
            [$adb, '-s', $serial, 'shell', 'getprop', 'dhcp.wlan0.ipaddress'],
        ];

        foreach ($cmds as $cmd) {
            try {
                $proc = new Process($cmd);
                $proc->setTimeout(5);
                $proc->run();
                $out = $proc->getOutput();

                // استخراج أول IP خاص (private) من المخرجات
                if (preg_match_all('/\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b/', $out, $matches)) {
                    foreach ($matches[1] as $ip) {
                        // تحقق أنه IP خاص حقيقي وليس 127.x أو 0.x
                        if (
                            !str_starts_with($ip, '127.') &&
                            !str_starts_with($ip, '0.')   &&
                            !str_starts_with($ip, '255.') &&
                            filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE) === false
                        ) {
                            return $ip;
                        }
                    }
                }
            } catch (\Throwable $e) {
                continue;
            }
        }

        return null;
    }
}

