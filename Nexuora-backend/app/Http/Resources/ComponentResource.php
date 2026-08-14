<?php

namespace App\Http\Resources;

use Illuminate\Http\Resources\Json\JsonResource;

class ComponentResource extends JsonResource
{
    /**
     * Transform the resource into an array.
     *
     * @param  \Illuminate\Http\Request  $request
     * @return array
     */
    public function toArray($request)
    {
        return [
            'id'            => $this->id,
            'name'          => $this->name,
            'category_id'   => $this->category_id,
            'category_name' => optional($this->category)->name,
            'screen_data'   => $this->screen_data,
            'status'        => $this->status,
            'user_id'       => $this->user_id,
            'is_community'  => $this->is_community,
            'preview_image' => $this->preview_image,
            'import_count'  => $this->import_count,
            'created_at'    => $this->created_at,
            'updated_at'    => $this->updated_at
        ];
    }
}
