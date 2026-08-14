<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class UpdateComponentsAddUserFields extends Migration
{
    public function up()
    {
        Schema::table('components', function (Blueprint $table) {
            // صاحب الـ Widget
            $table->unsignedBigInteger('user_id')->nullable()->after('id');
            // صورة المعاينة (Preview)
            $table->string('preview_image')->nullable()->after('screen_data');
            // عدد مرات الاستيراد
            $table->integer('import_count')->default(0)->after('preview_image');
            // هل هو مجتمعي = 1 أم خاص = 0
            $table->tinyInteger('is_community')->default(0)->after('import_count');

            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    public function down()
    {
        Schema::table('components', function (Blueprint $table) {
            $table->dropColumn(['user_id', 'preview_image', 'import_count', 'is_community']);
        });
    }
}
