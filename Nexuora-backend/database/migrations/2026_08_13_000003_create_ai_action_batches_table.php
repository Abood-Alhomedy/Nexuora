<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateAiActionBatchesTable extends Migration
{
    public function up()
    {
        Schema::create('ai_action_batches', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('conversation_id');
            $table->unsignedBigInteger('message_id')->nullable();
            $table->unsignedBigInteger('project_id');
            $table->unsignedBigInteger('screen_id')->nullable();
            $table->enum('status', ['pending_confirmation', 'confirmed', 'executed', 'failed', 'cancelled'])->default('pending_confirmation');
            $table->json('action_descriptors'); // the Action Descriptors returned to Flutter
            $table->json('action_results')->nullable(); // reported back by Flutter after execution
            $table->json('execution_metadata')->nullable(); // timing, IDs assigned, etc.
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('updated_at')->nullable();

            $table->foreign('conversation_id')->references('id')->on('ai_conversations')->onDelete('cascade');
            $table->foreign('project_id')->references('id')->on('projects')->onDelete('cascade');
            $table->index(['conversation_id', 'status']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('ai_action_batches');
    }
}
