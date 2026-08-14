<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateAiMessagesTable extends Migration
{
    public function up()
    {
        Schema::create('ai_messages', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('conversation_id');
            $table->enum('role', ['user', 'assistant', 'system']);
            $table->longText('content');
            $table->string('intent')->nullable();
            $table->enum('confidence', ['high', 'medium', 'low'])->nullable();
            $table->json('metadata')->nullable(); // intent result, target info, etc.
            $table->timestamp('created_at')->useCurrent();

            $table->foreign('conversation_id')->references('id')->on('ai_conversations')->onDelete('cascade');
            $table->index('conversation_id');
        });
    }

    public function down()
    {
        Schema::dropIfExists('ai_messages');
    }
}
