<?php

namespace App\AI\Registry;

/**
 * WidgetRegistry — mirrors AppConstant.dart widget types.
 *
 * LLM cannot reference a widget type not present in this registry.
 * This is the closed set of widgets Nexuora actually supports.
 */
class WidgetRegistry
{
    /**
     * Complete widget registry mirroring AppConstant.dart constants.
     * Keys = widget subType strings used in ScreenJsonData JSON.
     */
    public static array $widgets = [
        'Scaffold' => [
            'label'             => 'Scaffold (Root)',
            'allowed_children'  => ['Column', 'Row', 'Container', 'Stack', 'List', 'Grid', 'PageView'],
            'required_properties' => [],
            'allowed_properties' => ['backgroundColor', 'resizeToAvoidBottomInset'],
            'events'            => [],
            'is_root'           => true,
        ],
        'Container' => [
            'label'             => 'Container',
            'allowed_children'  => ['Column', 'Row', 'Stack', 'Text', 'TextButton', 'Image', 'CircleImage',
                                     'Icon', 'IconButton', 'TextField', 'Card', 'List', 'Grid', 'PageView',
                                     'ClipRRect', 'ConstrainedBox', 'Opacity', 'RotatedBox', 'SizedBox',
                                     'Divider', 'LottieAnimation', 'TabBar', 'TabBarView'],
            'required_properties' => [],
            'allowed_properties' => ['width', 'height', 'color', 'borderRadius', 'padding', 'margin',
                                      'borderColor', 'borderWidth', 'boxShadow', 'alignment', 'gradient'],
            'events'            => ['onTap'],
        ],
        'Column' => [
            'label'             => 'Column',
            'allowed_children'  => ['*'], // accepts all
            'required_properties' => [],
            'allowed_properties' => ['mainAxisAlignment', 'crossAxisAlignment', 'mainAxisSize', 'isExpanded'],
            'events'            => [],
        ],
        'Row' => [
            'label'             => 'Row',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['mainAxisAlignment', 'crossAxisAlignment', 'mainAxisSize', 'isExpanded'],
            'events'            => [],
        ],
        'Stack' => [
            'label'             => 'Stack',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['alignment', 'fit', 'clipBehavior'],
            'events'            => [],
        ],
        'Text' => [
            'label'             => 'Text',
            'allowed_children'  => [],
            'required_properties' => ['text'],
            'allowed_properties' => ['text', 'fontSize', 'fontWeight', 'fontStyle', 'color', 'textAlign',
                                      'overflow', 'maxLines', 'letterSpacing', 'wordSpacing', 'height',
                                      'fontFamily', 'textDecoration'],
            'events'            => [],
        ],
        'TextButton' => [
            'label'             => 'TextButton',
            'allowed_children'  => [],
            'required_properties' => ['text'],
            'allowed_properties' => ['text', 'backgroundColor', 'foregroundColor', 'fontSize', 'fontWeight',
                                      'width', 'height', 'padding', 'margin', 'borderRadius', 'icon',
                                      'isExpanded', 'elevation'],
            'events'            => ['onPressed'],
        ],
        'TextField' => [
            'label'             => 'TextField',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['hintText', 'labelText', 'borderType', 'borderColor', 'borderRadius',
                                      'fillColor', 'isFilled', 'prefixIcon', 'suffixIcon', 'obscureText',
                                      'keyboardType', 'maxLines', 'fontSize', 'fontColor', 'isExpanded'],
            'events'            => ['onChanged', 'onSubmitted'],
        ],
        'Image' => [
            'label'             => 'Image',
            'allowed_children'  => [],
            'required_properties' => ['imageUrl'],
            'allowed_properties' => ['imageUrl', 'imageType', 'width', 'height', 'fit', 'borderRadius',
                                      'isExpanded'],
            'events'            => ['onTap'],
        ],
        'CircleImage' => [
            'label'             => 'CircleImage',
            'allowed_children'  => [],
            'required_properties' => ['imageUrl'],
            'allowed_properties' => ['imageUrl', 'imageType', 'radius', 'borderColor', 'borderWidth'],
            'events'            => ['onTap'],
        ],
        'Icon' => [
            'label'             => 'Icon',
            'allowed_children'  => [],
            'required_properties' => ['iconName'],
            'allowed_properties' => ['iconName', 'color', 'size'],
            'events'            => [],
        ],
        'IconButton' => [
            'label'             => 'IconButton',
            'allowed_children'  => [],
            'required_properties' => ['iconName'],
            'allowed_properties' => ['iconName', 'color', 'size', 'padding', 'tooltip'],
            'events'            => ['onPressed'],
        ],
        'Card' => [
            'label'             => 'Card',
            'allowed_children'  => ['Column', 'Row', 'Container', 'Stack', 'ListTile', 'Text'],
            'required_properties' => [],
            'allowed_properties' => ['elevation', 'color', 'borderRadius', 'margin', 'shadowColor'],
            'events'            => ['onTap'],
        ],
        'List' => [
            'label'             => 'ListView',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['axis', 'shrinkWrap', 'padding', 'isExpanded'],
            'events'            => [],
        ],
        'Grid' => [
            'label'             => 'GridView',
            'allowed_children'  => ['*'],
            'required_properties' => ['crossAxisCount'],
            'allowed_properties' => ['crossAxisCount', 'crossAxisSpacing', 'mainAxisSpacing',
                                      'childAspectRatio', 'shrinkWrap', 'padding', 'isExpanded'],
            'events'            => [],
        ],
        'ListTile' => [
            'label'             => 'ListTile',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['title', 'subtitle', 'leadingIcon', 'trailingIcon', 'tileColor',
                                      'dense', 'isThreeLine'],
            'events'            => ['onTap', 'onLongPress'],
        ],
        'CheckBox' => [
            'label'             => 'Checkbox',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['value', 'activeColor', 'checkColor', 'label'],
            'events'            => ['onChanged'],
        ],
        'Radio' => [
            'label'             => 'RadioButton',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['value', 'groupValue', 'activeColor', 'label'],
            'events'            => ['onChanged'],
        ],
        'Switch' => [
            'label'             => 'Switch',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['value', 'activeColor', 'inactiveColor'],
            'events'            => ['onChanged'],
        ],
        'SwitchListTile' => [
            'label'             => 'SwitchListTile',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['title', 'subtitle', 'value', 'activeColor'],
            'events'            => ['onChanged'],
        ],
        'CheckboxListTile' => [
            'label'             => 'CheckboxListTile',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['title', 'subtitle', 'value', 'activeColor'],
            'events'            => ['onChanged'],
        ],
        'SizedBox' => [
            'label'             => 'SizedBox',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['width', 'height'],
            'events'            => [],
        ],
        'Divider' => [
            'label'             => 'Divider',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['thickness', 'color', 'height', 'indent', 'endIndent'],
            'events'            => [],
        ],
        'DropDown' => [
            'label'             => 'Dropdown',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['items', 'hint', 'value', 'borderColor', 'borderRadius',
                                      'fillColor', 'isExpanded'],
            'events'            => ['onChanged'],
        ],
        'Slider' => [
            'label'             => 'Slider',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['min', 'max', 'value', 'activeColor', 'inactiveColor', 'isExpanded'],
            'events'            => ['onChanged'],
        ],
        'RatingBar' => [
            'label'             => 'RatingBar',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['initialRating', 'minRating', 'itemCount', 'itemSize', 'color'],
            'events'            => ['onRatingUpdate'],
        ],
        'ClipRRect' => [
            'label'             => 'ClipRRect',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['borderRadius'],
            'events'            => [],
        ],
        'ConstrainedBox' => [
            'label'             => 'ConstrainedBox',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['minWidth', 'maxWidth', 'minHeight', 'maxHeight'],
            'events'            => [],
        ],
        'Opacity' => [
            'label'             => 'Opacity',
            'allowed_children'  => ['*'],
            'required_properties' => ['opacity'],
            'allowed_properties' => ['opacity'],
            'events'            => [],
        ],
        'RotatedBox' => [
            'label'             => 'RotatedBox',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['quarterTurns'],
            'events'            => [],
        ],
        'PageView' => [
            'label'             => 'PageView',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['axis', 'physics', 'isExpanded', 'indicatorEffect'],
            'events'            => ['onPageChanged'],
        ],
        'TabBar' => [
            'label'             => 'TabBar',
            'allowed_children'  => ['Tab'],
            'required_properties' => [],
            'allowed_properties' => ['indicatorColor', 'labelColor', 'unselectedLabelColor', 'isScrollable'],
            'events'            => [],
        ],
        'TabBarView' => [
            'label'             => 'TabBarView',
            'allowed_children'  => ['TabView'],
            'required_properties' => [],
            'allowed_properties' => ['physics'],
            'events'            => [],
        ],
        'Tab' => [
            'label'             => 'Tab',
            'allowed_children'  => [],
            'required_properties' => ['text'],
            'allowed_properties' => ['text', 'icon'],
            'events'            => [],
        ],
        'TabView' => [
            'label'             => 'TabView',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => [],
            'events'            => [],
        ],
        'Calendar' => [
            'label'             => 'Calendar',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['calendarFormat', 'selectedColor', 'todayColor'],
            'events'            => ['onDaySelected'],
        ],
        'LottieAnimation' => [
            'label'             => 'LottieAnimation',
            'allowed_children'  => [],
            'required_properties' => ['animationUrl'],
            'allowed_properties' => ['animationUrl', 'width', 'height', 'repeat', 'animate'],
            'events'            => [],
        ],
        'CreditCardView' => [
            'label'             => 'CreditCardView',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['cardNumber', 'expiryDate', 'cardHolderName', 'cvvCode', 'cardBgColor'],
            'events'            => [],
        ],
        'OTPTextField' => [
            'label'             => 'OTPTextField',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['length', 'fieldWidth', 'borderColor', 'activeColor'],
            'events'            => ['onCompleted'],
        ],
        'LinearProgressIndicator' => [
            'label'             => 'LinearProgressIndicator',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['value', 'backgroundColor', 'color', 'isExpanded'],
            'events'            => [],
        ],
        'SearchBar' => [
            'label'             => 'SearchBar',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['hintText', 'fillColor', 'borderRadius', 'isExpanded'],
            'events'            => ['onChanged', 'onSubmitted'],
        ],
        'AudioPlayer' => [
            'label'             => 'AudioPlayer',
            'allowed_children'  => [],
            'required_properties' => ['audioUrl'],
            'allowed_properties' => ['audioUrl', 'width', 'height'],
            'events'            => [],
        ],
        'VideoPlayer' => [
            'label'             => 'VideoPlayer',
            'allowed_children'  => [],
            'required_properties' => ['videoUrl'],
            'allowed_properties' => ['videoUrl', 'width', 'height', 'autoPlay', 'looping'],
            'events'            => [],
        ],
        'YoutubePlayer' => [
            'label'             => 'YoutubePlayer',
            'allowed_children'  => [],
            'required_properties' => ['videoId'],
            'allowed_properties' => ['videoId', 'width', 'height', 'autoPlay'],
            'events'            => [],
        ],
        'WebView' => [
            'label'             => 'WebView',
            'allowed_children'  => [],
            'required_properties' => ['url'],
            'allowed_properties' => ['url', 'width', 'height', 'isExpanded'],
            'events'            => [],
        ],
        'GoogleMap' => [
            'label'             => 'GoogleMap',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['initialLat', 'initialLng', 'zoom', 'width', 'height', 'isExpanded'],
            'events'            => ['onMapCreated'],
        ],
        'ChipView' => [
            'label'             => 'Chip',
            'allowed_children'  => [],
            'required_properties' => ['label'],
            'allowed_properties' => ['label', 'backgroundColor', 'labelColor', 'avatar', 'padding'],
            'events'            => ['onTap', 'onDeleted'],
        ],
        'ImageIcon' => [
            'label'             => 'ImageIcon',
            'allowed_children'  => [],
            'required_properties' => ['imagePath'],
            'allowed_properties' => ['imagePath', 'color', 'size'],
            'events'            => [],
        ],
        'Appbar' => [
            'label'             => 'AppBar',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['title', 'backgroundColor', 'foregroundColor', 'elevation',
                                      'centerTitle', 'leadingIcon', 'actionIcons'],
            'events'            => [],
        ],
        'BottomNavigationBar' => [
            'label'             => 'BottomNavigationBar',
            'allowed_children'  => [],
            'required_properties' => [],
            'allowed_properties' => ['items', 'selectedItemColor', 'unselectedItemColor',
                                      'backgroundColor', 'type'],
            'events'            => ['onTap'],
        ],
        'leftDrawer' => [
            'label'             => 'Left Drawer',
            'allowed_children'  => ['*'],
            'required_properties' => [],
            'allowed_properties' => ['backgroundColor', 'width'],
            'events'            => [],
        ],
    ];

    /**
     * Check if a widget type is supported.
     */
    public static function isSupported(string $widgetType): bool
    {
        return isset(self::$widgets[$widgetType]);
    }

    /**
     * Check if a widget can have children.
     */
    public static function acceptsChildren(string $widgetType): bool
    {
        $widget = self::$widgets[$widgetType] ?? null;
        if (!$widget) return false;
        return !empty($widget['allowed_children']);
    }

    /**
     * Check if childType can be placed inside parentType.
     */
    public static function canAcceptChild(string $parentType, string $childType): bool
    {
        $parent = self::$widgets[$parentType] ?? null;
        if (!$parent) return false;
        $allowed = $parent['allowed_children'];
        if (in_array('*', $allowed)) return true;
        return in_array($childType, $allowed);
    }

    /**
     * Check if a property is allowed for a widget type.
     */
    public static function isPropertyAllowed(string $widgetType, string $property): bool
    {
        $widget = self::$widgets[$widgetType] ?? null;
        if (!$widget) return false;
        return in_array($property, $widget['allowed_properties']);
    }

    /**
     * Get a compact summary for LLM context (small payload).
     */
    public static function getCompactSummary(): array
    {
        $summary = [];
        foreach (self::$widgets as $type => $def) {
            $summary[] = [
                'type'  => $type,
                'label' => $def['label'],
                'has_children' => !empty($def['allowed_children']),
            ];
        }
        return $summary;
    }
}
