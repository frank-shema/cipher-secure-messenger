package com.cipher.auth.adapter.in.seed;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.cipher.auth.application.port.in.RegisterUserCommand;
import com.cipher.auth.application.port.in.RegisterUserUseCase;
import com.cipher.auth.application.port.out.UserRepository;
import com.cipher.shared.config.SeedProperties;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.boot.DefaultApplicationArguments;

@ExtendWith(MockitoExtension.class)
class DemoSeederTest {

    @Mock
    private UserRepository users;
    @Mock
    private RegisterUserUseCase registerUser;

    @Test
    void doesNothingWhenSeedingIsDisabled() {
        new DemoSeeder(new SeedProperties(false), users, registerUser).run(new DefaultApplicationArguments());

        verifyNoInteractions(users, registerUser);
    }

    @Test
    void registersOnlyTheMissingDemoUsers() {
        when(users.existsByUsername("alice")).thenReturn(true);
        when(users.existsByUsername("bob")).thenReturn(false);
        when(users.existsByUsername("echo")).thenReturn(false);

        new DemoSeeder(new SeedProperties(true), users, registerUser).run(new DefaultApplicationArguments());

        ArgumentCaptor<RegisterUserCommand> commands = ArgumentCaptor.forClass(RegisterUserCommand.class);
        verify(registerUser, Mockito.times(2)).register(commands.capture());
        assertThat(commands.getAllValues()).extracting(RegisterUserCommand::username).containsExactly("bob", "echo");
        assertThat(commands.getAllValues()).extracting(RegisterUserCommand::displayName).containsExactly("Bob", "Echo");
        verify(registerUser, never()).register(any(RegisterUserCommand.class) == null ? null
                : org.mockito.ArgumentMatchers.argThat(command -> "alice".equals(command.username())));
    }
}
