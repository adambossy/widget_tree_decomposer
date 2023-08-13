import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

class Node {
  final String name;
  final Node? parent;
  final List<Node> children;
  final String? source;
  final int? offset;
  final int? length;

  Node(this.name, {this.parent, this.source, this.offset, this.length})
      : children = [];
}

/*
Output from parsing create_new_post_widget.dart

Root
  MyApp
    build
      return
        GestureDetector
          Scaffold
            SafeArea
              Container
                Column
                  Align
                    Padding
                      Column
                        Row
                          Text
                        Padding
                          Container
                            Row
                              Expanded
                                Padding
                                  Text
                              Padding
                                PopupMenuButton
                        Padding
                          Row
                            Expanded
                              Padding
                                Form
                                  Column
                                    TextFormField
                                    TextFormField
                                    Padding
                                      Text
                  Padding
                    Column
                      FFButtonWidget
*/

class WidgetStateVisitor extends RecursiveAstVisitor<void> {
  final Node root;
  late Node currentNode;

  WidgetStateVisitor() : root = Node('Root') {
    currentNode = root;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.toString() == 'build') {
      super.visitMethodDeclaration(node);
    }
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    node.visitChildren(MethodInvocationVisitor(currentNode));

    // It's important to forgo the super() call to avoid matching nested return statements
    // TODO Extract this into a SimpleAstVisitor that only matches top-level return statements
    // super.visitReturnStatement(node);
  }
}

class MethodInvocationVisitor extends SimpleAstVisitor<void> {
  late Node root;
  late Node currentNode;

  MethodInvocationVisitor(Node root) {
    this.root = this.currentNode = root;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final subtree = Node(node.methodName.toString(),
        parent: currentNode,
        source: node.toSource(),
        offset: node.offset,
        length: node.length);
    buildTree(subtree, node);
    currentNode.children.add(subtree);
  }
}

Node buildTree(Node root, MethodInvocation methodInvocation) {
  for (var argument in methodInvocation.argumentList.arguments) {
    if (argument is! NamedExpression) continue;

    final name = argument.name.label.name;
    final expression = argument.expression;

    if (name == 'child' || name == 'body') {
      if (expression is MethodInvocation) {
        expression.accept(MethodInvocationVisitor(root));
      }
    } else if (name == 'children') {
      // This part is kind of annoying. argument.childEntities will return a list containing
      // ['children:', ListLiteral(...)] so we must grab the second object in the list. The
      // second loop iterates over the actual MethodInvocation objects in the argument list.
      final listLiteral = argument.childEntities.elementAt(1) as ListLiteral;
      for (var listEntity in listLiteral.childEntities) {
        if (listEntity is MethodInvocation) {
          listEntity.accept(MethodInvocationVisitor(root));
        }
      }
    }
  }

  return root;
}

Future<String> readFile(path) async {
  var file = File(path);
  return await file.readAsString();
}

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Please provide a file name as the first argument.');
    return;
  }

  final fileName = arguments[0];
  var code = await readFile(fileName);
  var parseResult = parseString(content: code, throwIfDiagnostics: false);

  final visitor = WidgetStateVisitor();
  parseResult.unit.accept(visitor);

  printTree(visitor.root);

  final file = File(fileName);
  await file.writeAsString(extractWidget(code, visitor.root),
      mode: FileMode.write);
}

String widgetMethod(String body) {
  /* 
  Widget <nameOfMethod><uniqueIdentifier>(BuildContext context} {
    ...
  }
  */
  final widget = Method((b) => b
    ..name = 'widget123'
    ..returns = refer('Widget')
    ..body = Code('return $body;'));
  final emitter = DartEmitter();
  final code = DartFormatter().format('${widget.accept(emitter)}');
  print(code);

  return code;
}

String extractWidget(String code, Node node) {
  // Navigate to the first leaf node
  Node currentNode = node;
  while (currentNode.children.isNotEmpty) {
    currentNode = currentNode.children.elementAt(0);
  }

  print('currentNode ${currentNode.name}');

  String replacement = 'widget123()';
  String newMethod = widgetMethod(currentNode.source!);
  String newCode = code.substring(0, currentNode.offset) +
      replacement +
      code.substring(currentNode.offset! + currentNode.length!) +
      newMethod;

  final _newCode = DartFormatter().format(newCode);

  print(_newCode);

  return _newCode;
}

class Replacer {
  Replacer(String input)
      : _string = input,
        _max = input.length;

  String get string => _string;
  String _string;
  final int _max;

  var _offset = 0;
  var _tabu = 0;

  void replace(int start, int end, String replacement) {
    assert(start >= 0, 'start must be ≥ 0');
    assert(end >= end, 'end must be ≥ start');
    assert(end <= _max, 'end must be ≤ string length');
    assert(start >= _tabu, 'replacement must not overlap');

    final length = end - start;
    final nstart = start + _offset;
    _string = _string.substring(0, nstart) +
        replacement +
        _string.substring(nstart + length);
    _offset += replacement.length;
    _offset -= length;
    _tabu = end;
  }
}

void printTree(Node node, [int indent = 0]) {
  print('${' ' * indent}${node.name} | ${node.offset} | ${node.length}');
  for (var child in node.children) {
    printTree(child, indent + 2);
  }
}
