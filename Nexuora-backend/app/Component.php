<?php

namespace App;

use Illuminate\Database\Eloquent\Model;

class Component extends Model
{
    protected $table = 'components';

    protected $fillable = [
        'name',
    	'category_id',
        'screen_data',
        'status',
        'user_id',
        'is_community',
        'preview_image',
        'import_count'
    ];

    public function category(){
        return $this->belongsTo(Category::class,'category_id','id');
    }
}
