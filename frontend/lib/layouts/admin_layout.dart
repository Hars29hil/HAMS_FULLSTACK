import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final int currentIndex;
  final Function(int) onNavigate;
  final VoidCallback onLogout;
  final List<String> menuLabels;
  final List<IconData> menuIcons;
  final bool hideSidebar;

  const AdminLayout({
    super.key,
    required this.child,
    required this.title,
    required this.currentIndex,
    required this.onNavigate,
    required this.onLogout,
    required this.menuLabels,
    required this.menuIcons,
    this.hideSidebar = false,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(widget.title),
              actions: [
                IconButton(icon: const Icon(LucideIcons.bell), onPressed: () {}),
                IconButton(icon: const Icon(LucideIcons.logOut), onPressed: widget.onLogout),
              ],
            ),
      drawer: isDesktop || widget.hideSidebar ? null : _buildDrawer(),
      body: Row(
        children: [
          if (isDesktop && !widget.hideSidebar) _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                if (isDesktop) _buildTopHeader(),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            width: 250,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Row(
              children: [
                Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                SizedBox(width: 8),
                Text('Search...', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          IconButton(icon: const Icon(LucideIcons.bell), onPressed: () {}),
          const SizedBox(width: 16),
          InkWell(
            onTap: widget.onLogout,
            child: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accentSoft,
                  child: Text('A', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 8),
                Text('Admin', style: TextStyle(fontWeight: FontWeight.w600)),
                Icon(LucideIcons.chevronDown, size: 16),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(child: _buildSidebarMenu()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(child: _buildSidebarMenu()),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      height: 70,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HAMS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: AppColors.accent)),
          Text('Hostel Attendance', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildSidebarMenu() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.menuLabels.length,
      itemBuilder: (context, index) {
        final icon = widget.menuIcons[index];
        final label = widget.menuLabels[index];
        final isActive = widget.currentIndex == index;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () {
              widget.onNavigate(index);
              if (MediaQuery.of(context).size.width <= 900) {
                Navigator.of(context).pop(); // close drawer
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: isActive ? AppColors.accent : AppColors.textMuted),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? AppColors.accent : AppColors.textMuted,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


