<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateAiConversationsTable extends Migration
{
    public function up()
    {
        Schema::create('ai_conversations', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id');
            $table->unsignedBigInteger('project_id');
            $table->string('title')->nullable();
            $table->string('current_intent')->nullable();
            $table->json('metadata')->nullable(); // collected_params, missing_params, conversation state
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->foreign('project_id')->references('id')->on('projects')->onDelete('cascade');
            $table->index(['user_id', 'project_id']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('ai_conversations');
    }
}
