/// A toolbar widget that provides drawing tools and controls for the whiteboard.
/// This widget includes tools for drawing, shapes, text, and various effects.

import 'package:flutter/material.dart';
import '../models/shape_type.dart';

/// The main toolbar widget that provides all drawing tools and controls.
/// It is organized into sections for different types of tools and features.
class Toolbar extends StatefulWidget {
  // Drawing tool states
  final Color selectedColor;
  final double selectedStrokeWidth;
  final bool isEraser;
  final bool isDashed;
  final bool isHighlight;
  final ShapeType? selectedShapeType;
  
  // Callback functions for tool actions
  final Function(Color) onColorSelected;
  final Function(double) onStrokeWidthSelected;
  final VoidCallback onEraserToggled;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onClear;
  final VoidCallback onDashedToggled;
  final VoidCallback onHighlightToggled;
  final Function(ShapeType?) onShapeTypeSelected;
  final Function(String) onTextAdded;
  final Function(double) onFontSizeChanged;
  final Function(String) onFontFamilyChanged;
  final Function(TextAlignment) onTextAlignmentChanged;
  final Function(BlendMode) onBlendModeChanged;
  final VoidCallback? onImageSelected;
  final bool isTeacher;

  const Toolbar({
    super.key,
    required this.selectedColor,
    required this.selectedStrokeWidth,
    required this.isEraser,
    required this.isDashed,
    required this.isHighlight,
    required this.selectedShapeType,
    required this.onColorSelected,
    required this.onStrokeWidthSelected,
    required this.onEraserToggled,
    required this.onUndo,
    required this.onRedo,
    required this.onClear,
    required this.onDashedToggled,
    required this.onHighlightToggled,
    required this.onShapeTypeSelected,
    required this.onTextAdded,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onTextAlignmentChanged,
    required this.onBlendModeChanged,
    this.onImageSelected,
    required this.isTeacher,
  });

  @override
  State<Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<Toolbar> {
  late double _currentStrokeWidth;

  @override
  void initState() {
    super.initState();
    _currentStrokeWidth = widget.selectedStrokeWidth;
  }

  @override
  void didUpdateWidget(Toolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStrokeWidth != widget.selectedStrokeWidth) {
      _currentStrokeWidth = widget.selectedStrokeWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSectionTitle('Drawing Tools'),
            _buildDrawingTools(),
            const SizedBox(height: 16),
            _buildSectionTitle('Colors'),
            _buildColorPicker(),
            const SizedBox(height: 16),
            _buildSectionTitle('Stroke Width'),
            _buildStrokeWidthSlider(),
            const SizedBox(height: 16),
            _buildSectionTitle('Shapes'),
            _buildShapeTools(),
            const SizedBox(height: 16),
            _buildSectionTitle('Text & Effects'),
            _buildTextTools(context),
            const SizedBox(height: 16),
            _buildSectionTitle('Actions'),
            _buildActionButtons(),
            if (widget.isTeacher && widget.onImageSelected != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: const Text('Insert Image'),
                  onPressed: widget.onImageSelected,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a section title with consistent styling.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Builds the basic drawing tools section (pen and eraser).
  Widget _buildDrawingTools() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolButton(
          icon: Icons.edit,
          isSelected: !widget.isEraser && widget.selectedShapeType == null,
          onTap: () {
            widget.onShapeTypeSelected(null);
            if (widget.isEraser) widget.onEraserToggled();
          },
          tooltip: 'Freehand Drawing',
        ),
        const SizedBox(width: 8),
        _buildToolButton(
          icon: Icons.auto_fix_high,
          isSelected: widget.isEraser,
          onTap: () {
            widget.onEraserToggled();
            if (widget.selectedShapeType != null) {
              widget.onShapeTypeSelected(null);
            }
          },
          tooltip: 'Eraser Tool',
        ),
      ],
    );
  }

  /// Builds the color picker section with predefined colors.
  Widget _buildColorPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Colors.black,
        Colors.red,
        Colors.green,
        Colors.blue,
        Colors.yellow,
        Colors.purple,
        Colors.orange,
        const Color.fromARGB(255, 142, 236, 217),
      ].map((color) {
        return GestureDetector(
          onTap: () => widget.onColorSelected(color),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.selectedColor == color ? Colors.blue : Colors.grey,
                width: widget.selectedColor == color ? 2 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Builds the stroke width slider for adjusting line thickness.
  Widget _buildStrokeWidthSlider() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.line_weight),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Slider(
            value: _currentStrokeWidth,
            min: 1,
            max: 20,
            onChanged: (value) {
              setState(() {
                _currentStrokeWidth = value;
              });
              widget.onStrokeWidthSelected(value);
            },
          ),
        ),
        Text('${_currentStrokeWidth.toStringAsFixed(1)}'),
      ],
    );
  }

  /// Builds the shape tools section with various geometric shapes.
  Widget _buildShapeTools() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildToolButton(
          icon: Icons.straighten,
          isSelected: widget.selectedShapeType == ShapeType.line,
          onTap: () => widget.onShapeTypeSelected(ShapeType.line),
          tooltip: 'Line Tool',
        ),
        _buildToolButton(
          icon: Icons.rectangle_outlined,
          isSelected: widget.selectedShapeType == ShapeType.rectangle,
          onTap: () => widget.onShapeTypeSelected(ShapeType.rectangle),
          tooltip: 'Rectangle Tool',
        ),
        _buildToolButton(
          icon: Icons.circle_outlined,
          isSelected: widget.selectedShapeType == ShapeType.ellipse,
          onTap: () => widget.onShapeTypeSelected(ShapeType.ellipse),
          tooltip: 'Circle Tool',
        ),
        _buildToolButton(
          icon: Icons.change_history,
          isSelected: widget.selectedShapeType == ShapeType.triangle,
          onTap: () => widget.onShapeTypeSelected(ShapeType.triangle),
          tooltip: 'Triangle Tool',
        ),
        _buildToolButton(
          icon: Icons.arrow_forward,
          isSelected: widget.selectedShapeType == ShapeType.arrow,
          onTap: () => widget.onShapeTypeSelected(ShapeType.arrow),
          tooltip: 'Single Arrow Tool',
        ),
        _buildToolButton(
          icon: Icons.compare_arrows,
          isSelected: widget.selectedShapeType == ShapeType.doubleArrow,
          onTap: () => widget.onShapeTypeSelected(ShapeType.doubleArrow),
          tooltip: 'Double Arrow Tool',
        ),
        _buildToolButton(
          icon: Icons.format_strikethrough,
          isSelected: widget.isDashed,
          onTap: widget.onDashedToggled,
          tooltip: 'Dashed Line Style',
        ),
        _buildToolButton(
          icon: Icons.highlight,
          isSelected: widget.isHighlight,
          onTap: widget.onHighlightToggled,
          tooltip: 'Highlight Mode',
        ),
      ],
    );
  }

  /// Builds the text and effects tools section.
  Widget _buildTextTools(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolButton(
              icon: Icons.text_fields,
              isSelected: false,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => _TextInputDialog(
                    onTextAdded: (text) {
                      // First add the text to the whiteboard
                      widget.onTextAdded(text);
                      // Then show the text style dialog
                      showDialog(
                        context: context,
                        builder: (context) => _TextStyleDialog(
                          onFontSizeChanged: widget.onFontSizeChanged,
                          onFontFamilyChanged: widget.onFontFamilyChanged,
                          onTextAlignmentChanged: widget.onTextAlignmentChanged,
                          onDelete: () {
                            // Close the style dialog
                            Navigator.of(context).pop();
                            // Notify parent to delete the text
                            widget.onTextAdded(''); // Empty text will trigger deletion
                          },
                        ),
                      );
                    },
                    onFontSizeChanged: widget.onFontSizeChanged,
                    onFontFamilyChanged: widget.onFontFamilyChanged,
                    onTextAlignmentChanged: widget.onTextAlignmentChanged,
                  ),
                );
              },
              tooltip: 'Add Text',
            ),
            if (widget.isHighlight) ...[
              const SizedBox(width: 8),
              DropdownButton<BlendMode>(
                value: BlendMode.srcOver,
                items: [
                  DropdownMenuItem(
                    value: BlendMode.srcOver,
                    child: const Text('Normal'),
                  ),
                  DropdownMenuItem(
                    value: BlendMode.multiply,
                    child: const Text('Multiply'),
                  ),
                  DropdownMenuItem(
                    value: BlendMode.screen,
                    child: const Text('Screen'),
                  ),
                  DropdownMenuItem(
                    value: BlendMode.overlay,
                    child: const Text('Overlay'),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    widget.onBlendModeChanged(mode);
                  }
                },
                hint: const Text('Blend Mode'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Builds the action buttons section (undo, redo, clear).
  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildToolButton(
          icon: Icons.undo,
          isSelected: false,
          onTap: widget.onUndo,
          tooltip: 'Undo',
        ),
        const SizedBox(width: 8),
        _buildToolButton(
          icon: Icons.redo,
          isSelected: false,
          onTap: widget.onRedo,
          tooltip: 'Redo',
        ),
        const SizedBox(width: 8),
        _buildToolButton(
          icon: Icons.delete,
          isSelected: false,
          onTap: widget.onClear,
          tooltip: 'Clear All',
        ),
      ],
    );
  }

  /// Builds a tool button with consistent styling.
  Widget _buildToolButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: 36,
            height: 36,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.black87,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// A dialog for entering text to be added to the whiteboard.
class _TextInputDialog extends StatefulWidget {
  final Function(String) onTextAdded;
  final Function(double) onFontSizeChanged;
  final Function(String) onFontFamilyChanged;
  final Function(TextAlignment) onTextAlignmentChanged;

  const _TextInputDialog({
    required this.onTextAdded,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onTextAlignmentChanged,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

/// The state class for the text input dialog.
class _TextInputDialogState extends State<_TextInputDialog> {
  final _textController = TextEditingController();
  double _fontSize = 16.0;
  String _fontFamily = 'Arial';
  TextAlignment _textAlignment = TextAlignment.left;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Handles the addition of text to the whiteboard.
  void _handleAdd() {
    if (_textController.text.isNotEmpty) {
      // First add the text to the whiteboard
      widget.onTextAdded(_textController.text);
      
      // Close the current dialog
      Navigator.of(context).pop();
      
      // Show the text style dialog
      showDialog(
        context: context,
        builder: (context) => _TextStyleDialog(
          onFontSizeChanged: widget.onFontSizeChanged,
          onFontFamilyChanged: widget.onFontFamilyChanged,
          onTextAlignmentChanged: widget.onTextAlignmentChanged,
          onDelete: () {
            // Close the style dialog
            Navigator.of(context).pop();
            // Notify parent to delete the text
            widget.onTextAdded(''); // Empty text will trigger deletion
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Text'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Enter text',
              hintText: 'Type your text here',
            ),
            autofocus: true,
            maxLines: 5,
            onSubmitted: (_) => _handleAdd(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Font Size:'),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 8,
                  max: 72,
                  divisions: 32,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value;
                    });
                    widget.onFontSizeChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _fontFamily,
            items: [
              'Arial',
              'Times New Roman',
              'Courier New',
              'Georgia',
              'Verdana',
            ].map((family) {
              return DropdownMenuItem(
                value: family,
                child: Text(family),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _fontFamily = value;
                });
                widget.onFontFamilyChanged(value);
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.format_align_left),
                onPressed: () {
                  setState(() {
                    _textAlignment = TextAlignment.left;
                  });
                  widget.onTextAlignmentChanged(TextAlignment.left);
                },
                color: _textAlignment == TextAlignment.left ? Colors.blue : null,
              ),
              IconButton(
                icon: const Icon(Icons.format_align_center),
                onPressed: () {
                  setState(() {
                    _textAlignment = TextAlignment.center;
                  });
                  widget.onTextAlignmentChanged(TextAlignment.center);
                },
                color: _textAlignment == TextAlignment.center ? Colors.blue : null,
              ),
              IconButton(
                icon: const Icon(Icons.format_align_right),
                onPressed: () {
                  setState(() {
                    _textAlignment = TextAlignment.right;
                  });
                  widget.onTextAlignmentChanged(TextAlignment.right);
                },
                color: _textAlignment == TextAlignment.right ? Colors.blue : null,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _handleAdd,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// A dialog for adjusting text style properties.
class _TextStyleDialog extends StatefulWidget {
  final Function(double) onFontSizeChanged;
  final Function(String) onFontFamilyChanged;
  final Function(TextAlignment) onTextAlignmentChanged;
  final VoidCallback onDelete;

  const _TextStyleDialog({
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onTextAlignmentChanged,
    required this.onDelete,
  });

  @override
  State<_TextStyleDialog> createState() => _TextStyleDialogState();
}

/// The state class for the text style dialog.
class _TextStyleDialogState extends State<_TextStyleDialog> {
  double _fontSize = 16.0;
  String _fontFamily = 'Arial';
  TextAlignment _textAlignment = TextAlignment.left;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Text Style'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('Font Size:'),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 8,
                  max: 72,
                  divisions: 32,
                  label: _fontSize.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value;
                    });
                    widget.onFontSizeChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: _fontFamily,
            items: [
              'Arial',
              'Times New Roman',
              'Courier New',
              'Georgia',
              'Verdana',
            ].map((family) {
              return DropdownMenuItem(
                value: family,
                child: Text(family),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _fontFamily = value;
                });
                widget.onFontFamilyChanged(value);
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.format_align_left),
                onPressed: () {
                  setState(() {
                    _textAlignment = TextAlignment.left;
                  });
                  widget.onTextAlignmentChanged(TextAlignment.left);
                },
                color: _textAlignment == TextAlignment.left ? Colors.blue : null,
              ),
              IconButton(
                icon: const Icon(Icons.format_align_center),
                onPressed: () {
                  setState(() {
                    _textAlignment = TextAlignment.center;
                  });
                  widget.onTextAlignmentChanged(TextAlignment.center);
                },
                color: _textAlignment == TextAlignment.center ? Colors.blue : null,
              ),
              IconButton(
                icon: const Icon(Icons.format_align_right),
                onPressed: () {
                  setState(() {
                    _textAlignment = TextAlignment.right;
                  });
                  widget.onTextAlignmentChanged(TextAlignment.right);
                },
                color: _textAlignment == TextAlignment.right ? Colors.blue : null,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onDelete,
          child: const Text('Delete'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
 