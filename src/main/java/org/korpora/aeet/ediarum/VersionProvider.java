package org.korpora.aeet.ediarum;

import picocli.CommandLine.IVersionProvider;

import java.io.IOException;
import java.util.Objects;
import java.util.Properties;

public class VersionProvider implements IVersionProvider {

    /**
     *
     * @return version number defined in
     * {@code src/main/resources/properties/project.properties}
     * @throws IOException when file broken/unavailable
     */
    @Override
    public String[] getVersion() throws IOException {
        final Properties properties = new Properties();
        properties.load(Objects.requireNonNull(this.getClass().getClassLoader()
                .getResourceAsStream("project.properties")));
        String version = properties.getProperty("version");
        return new String[] { version };
    }

}
