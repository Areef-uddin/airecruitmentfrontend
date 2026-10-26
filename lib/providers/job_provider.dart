import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/job_model.dart';
import '../repositories/job_repository.dart';

final jobRepositoryProvider = Provider<JobRepository>((ref) => JobRepository());

final jobsListProvider = FutureProvider.autoDispose<List<JobModel>>((ref) async {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getJobs();
});

final recommendedJobsProvider = FutureProvider.autoDispose<List<JobModel>>((ref) async {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getRecommendedJobs();
});

final savedJobsProvider = FutureProvider.autoDispose<List<JobModel>>((ref) async {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getSavedJobs();
});

final myPostedJobsProvider = FutureProvider.autoDispose<List<JobModel>>((ref) async {
  final repo = ref.watch(jobRepositoryProvider);
  return repo.getJobs(mineOnly: true);
});
