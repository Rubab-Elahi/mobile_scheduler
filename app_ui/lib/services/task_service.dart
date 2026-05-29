import 'package:amplify_flutter/amplify_flutter.dart';

import 'dart:convert';

class TaskService {
  // ── GraphQL Queries ─────────────────────────────────────────
  static const String listTasksQuery = '''
    query ListTasks(\$userId: String!) {
      listTasks(userId: \$userId) {
        taskId
        title
        priority
        status
        dueDate
      }
    }
  ''';

  // ── Methods ────────────────────────────────────────────────
  Future<List<dynamic>> fetchTasks(String userId) async {
    try {
      final request = GraphQLRequest<String>(
         document: listTasksQuery,
         variables: {'userId': userId},
      );
      final response = await Amplify.API.query(request: request).response;
      
      if (response.data != null) {
        safePrint('Fetched tasks string: \${response.data}');
        final decoded = json.decode(response.data!);
        if (decoded is Map && decoded.containsKey('listTasks')) {
          return decoded['listTasks'] as List<dynamic>;
        }
      }
      return [];
    } on GraphQLResponseError catch (e) {
      safePrint('Errors: \${e.message}');
      return [];
    } catch (e) {
      safePrint('Error fetching tasks: \$e');
      return [];
    }
  }

  Future<void> triggerVoiceAI(String prompt) async {
    try {
      // Calling the REST API (Agentic AI Service)
      final restOperation = Amplify.API.post(
        '/ai/chat',
        body: HttpPayload.json({'prompt': prompt}),
      );
      final response = await restOperation.response;
      safePrint('AI Response: \${response.decodeBody()}');
    } on Exception catch (e) {
      safePrint('REST Error: \$e');
    }
  }
}
