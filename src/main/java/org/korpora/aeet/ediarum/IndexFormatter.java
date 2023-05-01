package org.korpora.aeet.ediarum;

import net.sf.saxon.s9api.*;
import org.korpora.useful.XMLUtilities;
import org.w3c.dom.Document;
import org.xml.sax.InputSource;

import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.sax.SAXSource;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Path;
import java.util.Properties;
import java.util.concurrent.Callable;

import picocli.CommandLine;
import picocli.CommandLine.Command;
import picocli.CommandLine.Parameters;


@Command(mixinStandardHelpOptions = true, description = "format index for Ediarum in Oxygen", versionProvider = VersionProvider.class)
public class IndexFormatter implements Callable<Integer> {


    /**
     * kinds of indices supported, names are in sync with index-formatter.xql
     */
    public enum IndexType {
        persons,
        places,
        items,
        organisations,
        bibliography,
    }

    @Parameters(index = "0", description = "input file")
    private Path inputFile;

    @Parameters(index = "1", paramLabel = "Type", description = "Index Type,"
            + " one of: ${COMPLETION-CANDIDATES}")

    private IndexType indexTypeEnum;

    public static void main(String[] args) {
        int exitCode = new CommandLine(new IndexFormatter())
                .execute(args);
        System.exit(exitCode);
    }

    public Integer call() {
        System.out.format("Going to format '%s' [type '%s']\n", inputFile, indexTypeEnum.toString());
        format(indexTypeEnum, inputFile.toFile());
        return 0;
    }

    /**
     * format index; pass arguments as String. Validation by recasting.
     * @param indexTypeString the index type, refer to {@link IndexType}.
     * @param inputFile the index file
     */
    private static void format(String indexTypeString, String inputFile) {
        var indexTypeEnum = IndexType.valueOf(indexTypeString);
        var inputFilePath = Path.of(inputFile);
        format(indexTypeEnum, inputFilePath.toFile());
    }

    /**
     * format index to XML
     * @param indexType the index type, refer to {@link IndexType}.
     * @param inputFilePath the index file
     */
    private static void format(IndexType indexType, Path inputFilePath) {
        format(indexType, inputFilePath.toFile());
    }

    /**
     * format index to XML
     * @param indexType the index type, refer to {@link IndexType}.
     * @param inputFile the index file
     */
    private static void format(IndexType indexType, File inputFile) {
        try (InputStream formatXQL = IndexFormatter.class.getClassLoader().getResourceAsStream("index-formatter.xql"); InputStream indexStream = new FileInputStream(inputFile)) {
            String indexTypeString = indexType.toString();
            Processor proc = new Processor(false);
            XQueryCompiler comp = proc.newXQueryCompiler();
            XQueryExecutable exp = comp.compile(formatXQL);

            DocumentBuilderFactory docFactory = DocumentBuilderFactory.newInstance();
            docFactory.setNamespaceAware(true);
            Document document = docFactory.newDocumentBuilder().newDocument();

            SAXSource indexSource = new SAXSource(new InputSource(indexStream));
            XQueryEvaluator qe = exp.load();
            qe.setExternalVariable(new QName("ediarum-index-id"), new XdmAtomicValue(indexTypeString));
            qe.setExternalVariable(new QName("entries"), proc.newDocumentBuilder().wrap(indexSource));
            qe.run(new DOMDestination(document));

            System.err.println(XMLUtilities.documentToString(document, true, false));


        } catch (IOException e) {
            throw new RuntimeException(e);
        } catch (SaxonApiException | ParserConfigurationException e) {
            throw new RuntimeException(e);
        }
    }
}