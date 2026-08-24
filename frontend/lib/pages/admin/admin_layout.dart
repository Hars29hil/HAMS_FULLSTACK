import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/app_colors.dart';

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
      extendBodyBehindAppBar: true,
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(widget.title),
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: AppColors.bg.withValues(alpha: 0.5),
                  ),
                ),
              ),
              actions: [
                IconButton(icon: const Icon(LucideIcons.bell), onPressed: () {}),
                IconButton(icon: const Icon(LucideIcons.logOut), onPressed: widget.onLogout),
              ],
            ),
      drawer: isDesktop || widget.hideSidebar ? null : _buildDrawer(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: null,
        ),
        child: Row(
          children: [
            if (isDesktop && !widget.hideSidebar) _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  if (isDesktop) _buildTopHeader(),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: isDesktop ? 0 : kToolbarHeight + MediaQuery.of(context).padding.top),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: 0.5),
              ),
              const Spacer(),
              Container(
                width: 280,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.bg.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: AppColors.text, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(LucideIcons.bell, size: 20, color: AppColors.text),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: widget.onLogout,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent]),
                        ),
                        child: const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.bg,
                          child: Text('A', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Admin', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.bgElevated,
      child: Column(
        children: [
          _buildSidebarHeader(),
          Expanded(child: _buildSidebarMenu()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 280,
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
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      height: 76,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accent]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.fingerprint, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HAMS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
              Text('Hostel Admin', style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarMenu() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
            borderRadius: BorderRadius.circular(12),
            splashColor: AppColors.accentSoft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: isActive ? const LinearGradient(colors: [AppColors.accent, AppColors.accent]) : null,
                color: isActive ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ] : [],
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: isActive ? Colors.white : AppColors.textMuted),
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textMuted,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 15,
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
