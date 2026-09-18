package com.example.taskmanager.controller;

import com.example.taskmanager.model.UserCova;
import com.example.taskmanager.repository.UserRepository;
import com.example.taskmanager.security.JwtService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JwtService jwtService;

    private BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    // Route : POST /api/auth/register
    @PostMapping("/register")
    public ResponseEntity<?> register(@RequestBody UserCova user) {
        if (userRepository.existsByEmail(user.getEmail())) {
            return ResponseEntity.badRequest().body("Cet email est déjà utilisé.");
        }
        // Hachage du mot de passe
        user.setPassword(passwordEncoder.encode(user.getPassword()));
        userRepository.save(user);
        return ResponseEntity.ok("Utilisateur inscrit avec succès !");
    }

    // Route : POST /api/auth/login
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody Map<String, String> loginData) {
        String email = loginData.get("email");
        String password = loginData.get("password");

        UserCova user = userRepository.findByEmail(email).orElse(null);

        if (user == null || !passwordEncoder.matches(password, user.getPassword())) {
            return ResponseEntity.status(401).body("Email ou mot de passe incorrect.");
        }

        Map<String, Object> response = new HashMap<>();
        response.put("message", "Connexion réussie !");
        response.put("userId", user.getId());
        response.put("email", user.getEmail());
        response.put("token", jwtService.generateToken(user.getEmail(), user.getId()));

        return ResponseEntity.ok(response);
    }
}