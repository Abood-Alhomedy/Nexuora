<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateAiUsageTable extends Migration
{
    public function up()
    {
        Schema::create('ai_usage', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id');
            $table->unsignedBigInteger('project_id')->nullable();
            $table->unsignedBigInteger('conversation_id')->nullable();
            $table->string('provider');
            $table->string('model');
            $table->integer('input_tokens')->default(0);
            $table->integer('output_tokens')->default(0);
            $table->integer('latency_ms')->default(0);
            $table->integer('request_count')->default(1);
            $table->enum('status', ['success', 'failed', 'rate_limited', 'timeout'])->default('success');
            $table->string('error_type')->nullable();
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->index(['user_id', 'created_at']);
            $table->index(['provider', 'model']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('ai_usage');
    }
}
