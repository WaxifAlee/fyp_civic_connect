import '../../../models/report.dart';

/// Deliberately isolated sample records. Never persisted to a backend.
abstract final class PreviewReports {
  static const citizenId = 'demo-citizen';
  static final List<Report> reports = [
    Report(
        id: 'demo-1',
        title: 'Streetlight out near the main market',
        description:
            'The streetlight near the market entrance has been out for several evenings. This stretch is difficult to see after sunset.',
        category: 'Electricity & Gas Department',
        status: 'in progress',
        reportedBy: citizenId,
        reporterName: 'Ayesha Khan',
        date: DateTime.now().subtract(const Duration(hours: 6)),
        location: '33.5520, 72.6330',
        reportCode: 'DEMO-EG001',
        upvotes: 18,
        upvotedBy: []),
    Report(
        id: 'demo-2',
        title: 'Damaged road surface on Hospital Road',
        description:
            'A section of the road has deep potholes. Rainwater collects here and makes it harder for pedestrians and vehicles to pass.',
        category: 'Public Works Department (PWD)',
        status: 'pending',
        reportedBy: citizenId,
        reporterName: 'Ayesha Khan',
        date: DateTime.now().subtract(const Duration(days: 1)),
        location: '33.5570, 72.6380',
        reportCode: 'DEMO-PW002',
        upvotes: 24,
        upvotedBy: []),
    Report(
        id: 'demo-3',
        title: 'Waste collection needed in the residential lane',
        description:
            'The shared collection point needs clearing. Please arrange collection and keep the pedestrian access clear.',
        category: 'Municipal Corportaion',
        status: 'resolved',
        reportedBy: citizenId,
        reporterName: 'Ayesha Khan',
        date: DateTime.now().subtract(const Duration(days: 3)),
        location: '33.5480, 72.6300',
        reportCode: 'DEMO-MC003',
        upvotes: 12,
        upvotedBy: []),
    Report(
        id: 'demo-4',
        title: 'Open drain cover beside the bus stop',
        description:
            'A drain cover is missing beside the bus stop. The opening is close to where people wait and needs a replacement cover.',
        category: 'Municipal Corportaion',
        status: 'in progress',
        reportedBy: 'demo-neighbour',
        reporterName: 'Omar Ahmed',
        date: DateTime.now().subtract(const Duration(days: 2)),
        location: '33.5540, 72.6290',
        reportCode: 'DEMO-MC004',
        upvotes: 31,
        upvotedBy: []),
    Report(
        id: 'demo-5',
        title: 'Footpath needs repair near the school',
        description:
            'Loose paving stones make this footpath uneven. Repairing the section would improve access for children and older residents.',
        category: 'Public Works Department (PWD)',
        status: 'resolved',
        reportedBy: 'demo-neighbour-2',
        reporterName: 'Sara Malik',
        date: DateTime.now().subtract(const Duration(days: 5)),
        location: '33.5510, 72.6350',
        reportCode: 'DEMO-PW005',
        upvotes: 15,
        upvotedBy: []),
  ];
}
