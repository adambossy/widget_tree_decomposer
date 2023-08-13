import 'dart:io';
import 'dart:convert'; // for utf8.encode

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:crypto/crypto.dart';
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
  late ClassDeclaration parentClass;

  WidgetStateVisitor() : root = Node('Root') {
    currentNode = root;
  }

  // @override
  // void visitClassDeclaration(ClassDeclaration node) {
  //   print('visiting classDeclaration ${node.name}');
  //   super.visitClassDeclaration(node);
  // }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    print('visiting methodDeclaration ${node.name}');
    AstNode? parent = node.parent;
    if (node.name.toString() == 'build' && parent != null) {
      if (parent is ClassDeclaration) {
        parentClass = parent;
        node.accept(ReturnStatementVisitor(currentNode));
      }
      // super.visitMethodDeclaration(node);
    }
  }
}

class ReturnStatementVisitor extends RecursiveAstVisitor<void> {
  late Node root;
  late Node currentNode;

  ReturnStatementVisitor(Node root) {
    this.root = currentNode = root;
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    print('visiting returnStatement ${node.expression}');
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
    this.root = currentNode = root;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.toString();
    if (!name.startsWith('widget')) {
      final subtree = Node(name,
          parent: currentNode,
          source: node.toSource(),
          offset: node.offset,
          length: node.length);
      buildTree(subtree, node);
      currentNode.children.add(subtree);
    }
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

  int iterations = 0;
  WidgetStateVisitor visitor;

  do {
    var code = await readFile(fileName);
    var parseResult = parseString(content: code, throwIfDiagnostics: false);

    visitor = WidgetStateVisitor();
    parseResult.unit.accept(visitor);

    printTree(visitor.root);

    if (visitor.root.children.isNotEmpty) {
      final file = File(fileName);
      await file.writeAsString(
          extractWidget(code, visitor.root, visitor.parentClass),
          mode: FileMode.write);
    }

    print('iterations $iterations');
    iterations++;
  } while (visitor.root.children.isNotEmpty && iterations < 1000);
}

String widgetMethod(String name, String body) {
  final contextParam = Parameter((b) => b
    ..name = 'context'
    ..type = refer('BuildContext'));

  final widget = Method((b) => b
    ..name = name
    ..returns = refer('Widget')
    ..requiredParameters.add(contextParam)
    ..body = Code('return $body;'));
  final emitter = DartEmitter();
  final code = DartFormatter().format('${widget.accept(emitter)}');
  print(code);

  return code;
}

String methodIdentifier(String widget) {
  final bytes = utf8.encode(widget); // data being hashed
  final digest = sha256.convert(bytes);
  return digest.toString().substring(0, 6);
}

String extractWidget(String code, Node node, ClassDeclaration parentClass) {
  // Navigate to the first leaf node
  Node currentNode = node;
  while (currentNode.children.isNotEmpty) {
    currentNode = currentNode.children.elementAt(0);
  }

  print('currentNode ${currentNode.name}');

  String identifier = methodIdentifier(code);
  String methodName = 'widget$identifier';
  String methodCall = '$methodName(context)';

  // Insert code into last position in parent class before the last parenthesis
  int insertionPoint = parentClass.offset + parentClass.length - 1;
  String methodCode = widgetMethod(methodName, currentNode.source!);
  String newCode = code.substring(0, insertionPoint) +
      methodCode +
      code.substring(insertionPoint);

  // Replace code with method call
  String before = newCode.substring(0, currentNode.offset);
  String after = newCode.substring(currentNode.offset! + currentNode.length!);
  newCode = before + methodCall + after;

  print(newCode);

  return DartFormatter().format(newCode);
}

void printTree(Node node, [int indent = 0]) {
  print('${' ' * indent}${node.name} | ${node.offset} | ${node.length}');
  for (var child in node.children) {
    printTree(child, indent + 2);
  }
}
