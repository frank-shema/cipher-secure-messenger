package com.cipher.shared.config;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.servlet.GenericServlet;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class CorrelationIdFilterTest {

    private CorrelationIdFilter filter;
    private MockHttpServletRequest request;
    private MockHttpServletResponse response;

    @BeforeEach
    void setUp() {
        filter = new CorrelationIdFilter();
        request = new MockHttpServletRequest("GET", "/health");
        response = new MockHttpServletResponse();
    }

    @Test
    void generatesCorrelationIdWhenHeaderIsMissing() throws Exception {
        filter.doFilter(request, response, new MockFilterChain());

        String generated = response.getHeader(CorrelationIdFilter.HEADER_NAME);
        assertThat(generated).isNotBlank();
        assertThat(UUID.fromString(generated)).isNotNull();
    }

    @Test
    void echoesIncomingCorrelationId() throws Exception {
        request.addHeader(CorrelationIdFilter.HEADER_NAME, "client-trace.42");

        filter.doFilter(request, response, new MockFilterChain());

        assertThat(response.getHeader(CorrelationIdFilter.HEADER_NAME)).isEqualTo("client-trace.42");
    }

    @Test
    void replacesIncomingCorrelationIdContainingUnsafeCharacters() throws Exception {
        String unsafe = "trace\ninjected=line";
        request.addHeader(CorrelationIdFilter.HEADER_NAME, unsafe);

        filter.doFilter(request, response, new MockFilterChain());

        String echoed = response.getHeader(CorrelationIdFilter.HEADER_NAME);
        assertThat(echoed).isNotEqualTo(unsafe);
        assertThat(UUID.fromString(echoed)).isNotNull();
    }

    @Test
    void exposesCorrelationIdInMdcDuringRequestAndClearsItAfterwards() throws Exception {
        request.addHeader(CorrelationIdFilter.HEADER_NAME, "mdc-trace");
        MdcCapturingServlet downstream = new MdcCapturingServlet();

        filter.doFilter(request, response, new MockFilterChain(downstream));

        assertThat(downstream.observedCorrelationId).isEqualTo("mdc-trace");
        assertThat(MDC.get(CorrelationIdFilter.MDC_KEY)).isNull();
    }

    private static final class MdcCapturingServlet extends GenericServlet {

        private String observedCorrelationId;

        @Override
        public void service(ServletRequest servletRequest, ServletResponse servletResponse) {
            observedCorrelationId = MDC.get(CorrelationIdFilter.MDC_KEY);
        }
    }
}
