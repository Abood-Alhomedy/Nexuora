<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
class CreateProjectMemoriesTable extends Migration
{
    public function up()
    {
        Schema::create('project_memories', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('project_id');
            $table->string('key', 100);
            $table->text('value');
            $table->string('type', 50)->default('project_fact');
            // type: project_fact | user_preference | design_rule | ui_fact
            $table->enum('importance', ['low', 'medium', 'high'])->default('medium');
            $table->unsignedBigInteger('source_conversation_id')->nullable();
            $table->timestamps();
            $table->foreign('project_id')
                ->references('id')->on('projects')
                ->onDelete('cascade');
            $table->foreign('source_conversation_id')
                ->references('id')->on('ai_conversations')
                ->onDelete('set null');
            // Unique per project+key — prevents contradictory memories
            $table->unique(['project_id', 'key']);
            // Indexes for efficient retrieval
            $table->index(['project_id', 'importance']);
            $table->index(['project_id', 'type']);
        });
    }
    public function down()
    {
        Schema::dropIfExists('project_memories');
    }
}