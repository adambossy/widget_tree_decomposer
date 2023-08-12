import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

class Node {
  final String name;
  final Node? parent;
  final List<Node> children;

  Node(this.name, {this.parent}) : children = [];
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
    currentNode = Node(node.name.toString(), parent: currentNode);
    root.children.add(currentNode);
    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.toString() == 'build') {
      final childNode = Node(node.name.toString(), parent: currentNode);
      currentNode.children.add(childNode);
      currentNode = childNode;
      super.visitMethodDeclaration(node);
    }
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    final childNode = Node('return', parent: currentNode);
    currentNode.children.add(childNode);
    currentNode = childNode;
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
    final subtree = Node(node.methodName.toString(), parent: currentNode);
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
}

void printTree(Node node, [int indent = 0]) {
  print('${' ' * indent}${node.name}');
  node.children.forEach((child) => printTree(child, indent + 2));
}
