import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'screens/authority_login_screen.dart';

class LoginRoleSelectorScreen extends StatelessWidget {
  const LoginRoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF0E3A7E);
    const Color secondaryColor = Color(0xFFFF7A00);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primaryColor, Color(0xFF1B5BA8)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  'Safety Safar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Traveler Safety & Emergency Management',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 48),
                _RoleCard(
                  icon: Icons.person_outline,
                  title: 'I am a Tourist',
                  subtitle: 'Traveler Login',
                  description: 'Access safety features, travel maps,\nalerts, and emergency services',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                  isPrimary: true,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                ),
                const SizedBox(height: 20),
                _RoleCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'I am an Authority',
                  subtitle: 'Government Official',
                  description: 'Authority dashboard, manage tourists,\nhandle incidents and approvals',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthorityLoginScreen())),
                  isPrimary: false,
                  primaryColor: primaryColor,
                  secondaryColor: secondaryColor,
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withAlpha(50), width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: primaryColor.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.lock_outline, size: 18, color: primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Secure & Verified',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'All communications are encrypted. Authority accounts require admin verification before access.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          fontFamily: 'Outfit',
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onPressed;
  final bool isPrimary;
  final Color primaryColor;
  final Color secondaryColor;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onPressed,
    this.isPrimary = false,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isPrimary ? widget.primaryColor : widget.secondaryColor.withAlpha(100),
              width: widget.isPrimary ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isPrimary ? widget.primaryColor.withAlpha(30) : Colors.black.withAlpha(20),
                blurRadius: _isHovered ? 16 : 8,
                offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isPrimary
                        ? [widget.primaryColor, const Color(0xFF1B5BA8)]
                        : [widget.secondaryColor, const Color(0xFFE66E00)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, size: 28, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: widget.primaryColor,
                          fontFamily: 'Outfit',
                        )),
                    const SizedBox(height: 2),
                    Text(widget.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: widget.isPrimary ? widget.primaryColor : widget.secondaryColor,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Outfit',
                        )),
                    const SizedBox(height: 6),
                    Text(widget.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                          height: 1.3,
                          fontFamily: 'Outfit',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16,
                  color: widget.isPrimary ? widget.primaryColor : Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
